function funcLogger() as object
    if m.global.funcLoggerState = invalid then
        m.global.addField("funcLoggerState", "assocarray", true)
        m.global.funcLoggerState = {
            _callStack: []
            _callsLog: []
            _absTime: CreateObject("roDateTime").asSeconds()

            ' use printLevels to controll prints from tracking node, eg `_.p("foo")` `_.warn("foo")` 
            ' use FunctionLogLevel to controll logging function calls, eg `logFunc("func", "tag", 1)` `logFunc("func", "tag", 2)`
            printLevels: {"off":0, "error":1, "warn":2, "info":3, "debug":4, "trace":5, "all":6} ' direction of including/nesting level <-, ref(https://stackoverflow.com/questions/7745885/log4j-logging-hierarchy-order)
            enabledTags: { ' empty tag_name `""` means - log all functions and added tags will be ignored, else - only for added tags logs will work
                "": [-1, "all"] ' all prints and logs are enabled
            } 
            ' scheme =     "tag_name": [FunctionLogLevel, printsLevel]
            ' if you added some tags and "" presented too - added tags will override FunctionLogLevel from `""` for propriate groups
            ' FunctionLogLevel - integer value, by default it = `0`, `-1` means enable `all`, else it works like `print if passedLevel <= FunctionLogLevel`, so `2` inclides `1 and 0`, bigger value cause more logs :)
            ' you can omit or write partly {Log/Print}Level for group and just type `"tag_name": []` or  `"tag_name": [-1]`, by default it will be as `[0, "debug"]`

            cachingMode: "none" ' "none" - relatime output, "full" - will collect all logs, "short" will collect logs only for current call stack
            printOffset: 4
            disableFuncLogger: false ' set as true for disabling all logs
            muteLogPrints: false ' set as true to disable prints inside function, note - it will not disable logging of function calls
            printComponentType: true
            printComponentID: false
            printCallContext: false ' print name of parent function
            printCallTime: false ' print time when function was called.
            measureExecTime: false ' will print execution time. NOTE: it is inaccurate, requires additional call `funcLogger()` after function executes
            ' print template: CallContext-->ComponentType::FuncName(ComponentID)   CallTime
        }

        ' patch groups values if you laze to input all values
        state = m.global.funcLoggerState
        for each tag in state.enabledTags.keys()
            group = state.enabledTags[tag]
            if group.count() = 0 then group.push(0)
            if group.count() = 1 then group.push("debug")
            state.enabledTags[tag] = group
        end for
        m.global.funcLoggerState = state
    end if

    _funcLogger = {
        _state : m.global.funcLoggerState
        _callContextName: ""

        _getExitTrackerNode: function (name)
            if m._state.cachingMode = "short" and m._state._callStack.count() = 0 then m._state._callsLog = [] ' clean logs
            newNode = CreateObject("roSGNode","Node")
            newNode.id = name
            m._state._callStack.push(newNode)
            fields = {
                muted: false
                lockFuncLoger: false
                globalMute: false
                enableComponentLock: false
            }
            if m._state.measureExecTime then fields.append({
                startTime: m._getCurrentTime()
                nestedTime: 0
            })
            newNode.addFields(fields)
            return newNode
        end function

        _updateCallStack: sub()
            lastFunc = m._state._callStack.peek()
            while lastFunc <> invalid
                if lastFunc.getParent() <> invalid then ' means that we reached last alive call
                    exit while
                else
                    m._state._callStack.pop()
                    lastFunc.enableComponentLock = false ' trigger that will disable local component lock
                    execTime = 0
                    if m._state.measureExecTime then ' log time how long node was alive(execution time)
                        execTime = m._getCurrentTime() - lastFunc.startTime
                        selfTime = execTime - lastFunc.nestedTime
                        if m._state.cachingMode = "none"
                            ?TAB(m._state._callStack.count() * m._state.printOffset) " <-- "lastFunc.id" => " execTime " (self - "selfTime")" ' let it here for performance
                        else
                            result = String(m._state._callStack.count() * m._state.printOffset, " ") + " <-- " + lastFunc.id+ " => "  + execTime.toStr() + " (self - " + selfTime.toStr() + ")"
                            m.print(result, true)
                        end if
                    end if
                end if
                lastFunc = m._state._callStack.peek()
                if m._state.measureExecTime and lastFunc <> invalid then lastFunc.nestedTime += execTime
            end while
            if m._state.printCallContext and lastFunc <> invalid then m._callContextName = " --> " + lastFunc.id
        end sub

        _setGlobalMute: sub(node as object, value as boolean)
            applyValue = false
            node.globalMute = value
            for each callTrackNode in m._state._callStack
                if node.isSameNode(callTrackNode) then applyValue = true
                if applyValue then callTrackNode.muted = value
            end for
        end sub

        _isMuted: function () as boolean
            if m._state.muteLogPrints = true then return true
            for each call in m._state._callStack
                result = call.globalMute
                if call.globalMute = true then return true
            end for
            return false
        end function

        _isLocked: function () as boolean
            result = false
            for each call in m._state._callStack
                result = call.lockFuncLoger
                if call.lockFuncLoger = true then exit for
            end for
            return result = true
        end function

        _getCurrentTime: function()
            now = CreateObject("roDateTime")
            return (now.asSeconds() - m._state._absTime) * 1000 + now.GetMilliseconds()
        end function

        _getCallTime: function () ' minutes:seconds.milliseconds
            if m._state.printCallTime = false then return ""
            now = CreateObject("roDateTime")
            return "   " + now.GetMinutes().toStr() + ":" + now.GetSeconds().toStr() + "." + now.GetMilliseconds().toStr()
        end function

        _isLogInEnabledTagGroup: function(logTag as string, funcitonLogLevel as integer)
            if m._state.enabledTags.count() = 0 then return true ' if enabledTags is empty - means that this feature is disabled
            for each tag in [logTag, ""]
                group = m._state.enabledTags[tag]
                if group <> invalid then 
                    groupLevel = group[0]
                    return groupLevel = -1 or funcitonLogLevel <= groupLevel
                end if
            end for
            return false
        end function

        _getPrintLevel: function(logTag)
            defaultLevel = m._state.printLevels["debug"]
            if m._state.enabledTags.count() = 0 then return defaultLevel ' if enabledTags is empty - means that this feature is disabled
            for each tag in [logTag, ""]
                group = m._state.enabledTags[tag]
                if group <> invalid then return m._state.printLevels[group[1]]
            end for
            return 0
        end function

        _buildFuntionLog: function (args)
            offset = m.getOffset()
            if m._state.printComponentID and args._top.id <> "" then args.funcName = args.funcName + "(" + args._top.id + ")"
            if m._state.printComponentType then
                if args._top <> invalid then componentName = args._top.subtype() else componentName = "Unknown"
                args.funcName = componentName + "::" + args.funcName
            end if

            if m._state.cachingMode = "none"
                ?TAB(offset) m._callContextName " --> " args.funcName m._getCallTime() ' let it here for performance - TAB vs String(offset, " ")
            else
                m.print(String(offset, " ") + m._callContextName + " --> " + args.funcName + m._getCallTime(), true)
            end if
            exitTrackerNode = m._getExitTrackerNode(args.funcName)
            functionExitingIndicator = CreateObject("roSGNode","Node")
            functionExitingIndicator.appendChild(exitTrackerNode)
            functionExitingIndicator.addFields({
                tab: String(offset + m._state.printOffset, " ") ' string offset
                trackerNode: exitTrackerNode
                printThroughFuncLogger: m._state.cachingMode <> "none"
                maxPrintLevel: m._getPrintLevel(args.logTag)
                printLevels: m._state.printLevels
            })
            m.saveState()
            return functionExitingIndicator
        end function

        '==================================== PUBLIC ========================================

        ' @description returns current indentation
        getOffset: function () as integer ' eg. ?TAB(funcLogger().getOffset()) "some print"
            m._updateCallStack()
            return m._state._callStack.count() * m._state.printOffset
        end function

        ' @description will disable funcLogger
        disable: function(isDisabled as boolean) ' will disable funcLogger
            m._state.disableFuncLogger = isDisabled
            m.saveSate()
        end function

        ' @description formatted log
        ' @param text - text that will be printed
        ' @param [args] - an array of args that will be used for substitution in `text`
        ' @param [ignoreIndentation=false] - determines whether `text` will be printed with current indentation
        printf: sub(text as object, args = [], ignoreIndentation = false) ' formatted log
            values = ["", "", "", ""]
            offset = m.getoffset()
            for i = 0 to args.count() - 1
                values[i] = convertToStr(args[i], offset)
            end for
            text = substitute(text, values[0], values[1], values[2], values[3])
            m.print(text, ignoreIndentation)
        end sub

        ' @description makes log that will be printed/cahced with correct indentation
        ' @param text - text that will be printed
        ' @param [ignoreIndentation=false] - determines whether `text` will be printed with current indentation
        print: sub(text as string, ignoreIndentation = false)
            if not ignoreIndentation then text = String(m.getOffset() + m._state.printOffset, " ") + text
            if m._state.cachingMode = "none"
                ?text
            else
                m._state._callsLog.push(text)
            end if
            m.saveState()
        end sub

        ' @description will print out all cached logs
        printLogs: sub()
            for each log in m._state._callsLog
                ?log
            end for
        end sub

        ' @description skipped `logFunc`
        ' @return {AssociativeArray} a mocked object that does ignore all actions
        xlogFunc: function(funcName as string)
            return __getFuncTrackerInterface({}, true)
        end function

        ' @description will log function and increase call stack
        ' @param {string} funcName - fucntion name
        ' @param {string} logTag - tag which will be use for enable/disable entire group of function logs, like "tts", "timers", "playback"
        ' @param {integer} funcitonLogLevel - controll level of log inside tag's group, bigger value means more detailed log
        ' @return {AssociativeArray} function tracker object that has interface for work with created log
        ' patterns for logging all function in file/project
        ' search pattern: (^ *(sub|function) *(.*)\(.*\).*$)
        ' replace pattern: $1\n    _ = logfunc("$3")\n
        logFunc: function(funcName as string, logTag = "" as string, funcitonLogLevel = 0 as integer)
            ctx = getGlobalAA()

            allowedLog = m._isLogInEnabledTagGroup(logTag, funcitonLogLevel)
            ignoreLog = m._state.disableFuncLogger = true or ctx.disableLogFunc = true or m._isLocked() = true or not allowedLog
            if ignoreLog then return __getFuncTrackerInterface({}, true)

            functionExitingIndicator = m._buildFuntionLog({
                _top: ctx.top
                funcName: funcName
                logTag: logTag
            })
            return __getFuncTrackerInterface(functionExitingIndicator).mute(m._isMuted())
        end function

        ' @description will update current state of global field, where we store state
        saveState: sub()
            getGlobalAA().global.funcLoggerState = m._state
        end sub

        updateState: sub() ' useless to call it directly, but let keep it
            m._updateCallStack()
            m.saveState()
        end sub
    }
    _funcLogger.updateState()
    return _funcLogger
end function

function __getFuncTrackerInterface(indicatorNode as object, useMock = false) as object
    if useMock then indicatorNode = {tab: "", trackerNode: {}}
    return {
        indicatorNode: indicatorNode
        trackerNode: indicatorNode.trackerNode
        tab: indicatorNode.tab

        _maxPrintLevel: indicatorNode.maxPrintLevel
        _printLevels: indicatorNode.printLevels
        _doNothing: useMock
        _textFormatter: _getTextFromatter(indicatorNode.tab.len(), 14)

        ' @description print return, will print return value + comment and line Num
        ' eg: `return _.pReturn(foo1 - foo2, "foo's diff", LINE_NUM)`
        pReturn: function(result, comment = "", lineNum = -1 as integer)
            lineNumtext = "" 
            if lineNum <> -1 then lineNumtext = "::line: " + lineNum.toStr() + ")"
            funcName = m.trackerNode.id
            m.info("$1, $2 \n'-- returns: $3",funcName + lineNumtext, comment, result)
            return result
        end function
        
        ' @description formatted print that will be printed/cahced with correct indentation
        error: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.error)
        end function
        
        ' @description formatted print that will be printed/cahced with correct indentation
        warn: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.warn)
        end function

        ' @description formatted print that will be printed/cahced with correct indentation
        info: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.info)
        end function

        ' @description formatted print that will be printed/cahced with correct indentation
        debug: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.debug)
        end function

        ' @description short alias to m.debug(...)
        p: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.debug)
        end function

        ' @description formatted print that will be printed/cahced with correct indentation
        trace: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            return m._print(text, [_0, _1, _2, _3], m._printLevels.trace)
        end function

        ' @description formatted log that will be printed/cahced with correct indentation
        _print: function (text as string, args as object, level as integer)
            if m._doNothing then return m
            if not m._isPrintAllowed(level) then return m
            if not m.trackerNode.muted then
                text = m._textFormatter.proccesText(text, args)
                ' text = substitute(text, _0, _1, _2, _3) ' old
                if not m.indicatorNode.printThroughFuncLogger
                    ?m.tab text
                else
                    funcLogger().print(m.tab + text, true)
                end if
            end if
            return m
        end function

        ' @description skipped print
        xp: sub(text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            ' relax, do nothing :D
        end sub

        ' @description will mute all prints for current function
        mute: function(isMute = true as boolean) as object
            m.trackerNode.muted = isMute
            return m
        end function

        ' @description will mute prints in all nested functions
        muteChildren: function(isMute = true as boolean) as object
            if m._doNothing then return m
            funcLogger()._setGlobalMute(m.trackerNode, isMute)
            return m
        end function

        ' @description will mute all prints for current function and nested functions
        muteAll: function(isMute = true as boolean) as object
            m.mute(isMute)
            m.muteChildren(isMute)
            return m
        end function

        ' @description will temporarily lock funcLogger for nested functions. Unlocks after function executes
        lockChildren: function(value = true as boolean) as object
            if m._doNothing then return m
            m.trackerNode.lockFuncLoger = value
            return m
        end function

        ' @description will permanently lock funcLogger for current component.
        ' same as `lockcomponent()`
        plock: function(value = true as boolean) as object
            if m._doNothing then return m
            getGlobalAA().disableLogFunc = value
            return m
        end function

        ' @description will temporarily lock funcLogger for current component. Unlocks after function executes
        tlock: function(value = true as boolean) as object
            if m._doNothing then return m
            getGlobalAA().disableLogFunc = value
            if not m.trackerNode.enableComponentLock then
                m.trackerNode.enableComponentLock = true
                m.trackerNode.observeField("enableComponentLock", "__disableComponentLock_CallBack")
            end if
            return m
        end function

        _isPrintAllowed: function(printLevel)
            return printLevel <= m._maxPrintLevel
        end function
    }
end function

' ======================================== GLOBAL PUBLIC FUNCTIONS =====================================


' @description same as `funcLogger().logFunc("...")`
' use it for log function call, and save returned value to variable
' example :
'   sub someFunc()
'       _ =  logfunc("someFunc")
'   end sub
function logFunc(funcName as string, logTag = "" as string, funcitonLogLevel = 0 as integer)
    if m.global = invalid then return __getFuncTrackerInterface({}, true)
    return funcLogger().logFunc(funcName, logTag, funcitonLogLevel)
end function

' @description same as `funcLogger().xlogFunc("...")`
function xlogFunc(funcName as string)
    return __getFuncTrackerInterface({}, true)
end function

' @description will permanently lock funcLogger for current component.
sub lockComponent(value = true as boolean)
    m.disableLogFunc = value
end sub

' @description will permanently unlock funcLogger for current component.
sub unlockComponent()
    m.disableLogFunc = false
end sub

' @description will return node path till last parent(scene in most cases)
' @param {boolean} includeId - will include nodes ID if it is not empty
function getNodePath(includeId = false as boolean)
    tryGetNodeId = function(node, includeId)
        if node.id = "" or  not includeId then return ""
        return "(" + node.id + ")"
    end function

    path = [m.top.subtype() + tryGetNodeId(m.top, includeId)]
    parent = m.top.getParent()
    while parent <> invalid

        path.Unshift(parent.subtype() + tryGetNodeId(parent, includeId))
        parent = parent.getParent()
    end while

    return path.join("->")
end function

' @description will convert any variable to string if it possible.
' @param obj -  object that will be converted to string
' @param [_tab] - which indentation should be applied for converted object
function convertToStr(obj, _tab = 0, wrapStringInQuotes = false)
    try ' avoid stakc overflow
        return __convertToStr(obj, _tab, wrapStringInQuotes)
    catch e
        ?"convertToStr::Error:: "e.message
        return ""
    end try
end function

function __convertToStr(obj, _tab = 0, wrapStringInQuotes = false)
    appendTab = function(text, _tab)
        return String(_tab, " ") + text
    end function
    tabSize = 4
    if type(obj) = "<uninitialized>" then return "<uninitialized>"
    if obj = invalid then return "invalid"
    if wrapStringInQuotes and (type(obj) = "String" or type(obj) = "roString") then obj = """" + obj + """"
    if GetInterface(obj, "ifToStr") <> invalid then return obj.toStr()
    if GetInterface(obj, "ifListToArray") <> invalid then obj = obj.toArray()
    if GetInterface(obj, "ifArray") <> invalid then
        values = []
        for each val in obj
            values.push(appendTab(convertToStr(val,_tab + tabSize, true),_tab + tabSize))
        end for
        return "[" + chr(10) + values.join(", " + chr(10)) + chr(10) + appendTab("]",_tab)
    end if
    if GetInterface(obj, "ifAssociativeArray") <> invalid then
        values = []
        for each field in obj.keys()
            value = convertToStr(obj[field], _tab + tabSize, true)
            values.push(appendTab(field + ": " + value, _tab + tabSize))
        end for
        return "{" + chr(10) + values.join(", " + chr(10)) + chr(10) + appendTab("}",_tab)
    end if
    return "null"
end function

function cut(obj, deep = 0)
    wrapObjectFunc = function(value, deep)
        if GetInterface(value, "ifArray") <> invalid or GetInterface(value, "ifAssociativeArray") <> invalid then
            if deep > 0 then
                return cut(value, deep - 1)
            else
                return "<Component: " + type(value) + "> items = " + value.count().toStr()
            end if
        end if
        return value
    end function

    if GetInterface(obj, "ifArray") <> invalid then
        newObj = []
        for each item in obj
            newObj.push(wrapObjectFunc(item, deep))
        end for
    else if GetInterface(obj, "ifAssociativeArray") <> invalid
        newObj = {}
        for each field in obj.keys()
            value = wrapObjectFunc(obj[field], deep)
            newObj[field] = value
        end for
    else
        return obj
    end if
    
    return newObj
end function

function cut1(obj)
    return cut(obj, 1)
end function

function cut2(obj)
    return cut(obj, 2)
end function

function cut3(obj)
    return cut(obj, 3)
end function

function cut4(obj)
    return cut(obj, 4)
end function

function cut5(obj)
    return cut(obj, 5)
end function

function _getTextFromatter(_offset = 0, _tabsize = 13)
    aa = {
        offset: _offset
        tabSize: _tabSize
        proccesText: function(text as string, args = [])
            text = m._preprocessReplaceMarkers(text)
            if convertToStr(args[0]) <> "" and text.inStr("{0}") = -1 then text += " {0}" ' fast print first argument without placeholder, eg `_.p("foo = ", 10)`
            text = m._safeSubstitute(text, args)
            text = m._postProccessingReplacement(text)
            return text
        end function

        _preprocessReplaceMarkers: function(text as string)
            if m.replaceMap = invalid then
                m.replaceMap = {}
                for each tag in ["t", "n"]
                    for i = 2 to 4
                        m.replaceMap["\" + i.toStr() + tag] = string(i, "\" + tag)
                    end for
                end for
                for i = 1 to 4
                    m.replaceMap["$" + i.toStr()] = "{" + (i - 1).toStr() + "}"
                end for
            end if
            for each key in m.replaceMap
                text = text.Replace(key, m.replaceMap[key])
            end for
            return text
        end function

        _safeSubstitute: function(text as string, args = [])
            values = ["", "", "", ""]
            for i = 0 to args.count() - 1
                values[i] = convertToStr(args[i], m.offset)
            end for
            text = substitute(text, values[0], values[1], values[2], values[3])
            return text
        end function

        _postProccessingReplacement:function(text)
            text = text.Replace("\n", chr(10) + "\n" + String(m.offset, " "))
            lines = text.split("\n")
            for i = 0 to lines.count() - 1
                text = lines[i]
                tabpos = Instr(1, text, "\t")
                if tabpos > 0
                    parts = []
                    while tabpos > 0
                        firstPart = text.left(tabpos-1)
                        additionalOffset = m.tabSize - (tabpos mod m.tabSize)
                        firstPart += string(additionalOffset, " ")
                        parts.push(firstPart)
                        text = text.mid(tabpos+1)
                        tabpos = Instr(1,text, "\t")
                    end while
                    parts.push(text)
                    lines[i] = parts.join("")
                end if
            end for
            text = lines.join("")
            return text
        end function
    }
    return aa
end function

' @description callback for automatically disable temporary component's lock
sub __disableComponentLock_CallBack(event as object)
    m.disableLogFunc = false
end sub
