function funcLogger() as object
    if m.global.funcLoggerState = invalid then
        m.global.addField("funcLoggerState", "assocarray", true)
        m.global.funcLoggerState = {
            _callStack: []
            _callsLog: []
            _absTime: CreateObject("roDateTime").asSeconds()

            cachingMode: "none" ' "none" - relatime output, "full" - will collect all logs, "short" will collect logs only for current call stack
            printOffset: 4
            disableFuncLogger: false ' set as true for disabling all logs
            printComponentType: true
            printComponentID: false
            printCallContext: false ' print name of parent function
            printCallTime: false ' print time when function was called.
            measureExecTime: false ' will print execution time. NOTE: it is inaccurate, requires additional call `funcLogger()` after function executes
            ' print template: CallContext-->ComponentType::FuncName(ComponentID)   CallTime
        }
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
                            m.log(result, true)
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
            result = false
            for each call in m._state._callStack
                result = call.globalMute
                if call.globalMute = true then exit for
            end for
            return result = true
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
                m.log(String(offset, " ") + m._callContextName + " --> " + args.funcName + m._getCallTime(), true)
            end if
            exitTrackerNode = m._getExitTrackerNode(args.funcName)
            functionExitingIndicator = CreateObject("roSGNode","Node")
            functionExitingIndicator.appendChild(exitTrackerNode)
            functionExitingIndicator.addFields({
                tab: String(offset + m._state.printOffset, " ") ' string offset
                trackerNode: exitTrackerNode
                printThroughFuncLogger: m._state.cachingMode <> "none"
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
        logf: sub(text as object, args = [], ignoreIndentation = false) ' formatted log
            values = ["", "", "", ""]
            offset = m.getoffset()
            for i = 0 to args.count() - 1
                values[i] = convertToStr(args[i], offset)
            end for
            text = substitute(text, values[0], values[1], values[2], values[3])
            m.log(text, ignoreIndentation)
        end sub

        ' @description makes log that will be printed/cahced with correct indentation
        ' @param text - text that will be printed
        ' @param [ignoreIndentation=false] - determines whether `text` will be printed with current indentation
        log: sub(text as string, ignoreIndentation = false)
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
        ' @return {AssociativeArray} function tracker object that has interface for work with created log
        ' patterns for logging all function in file/project
        ' search pattern: (^ *(sub|function) *(.*)\(.*\).*$)
        ' replace pattern: $1\n    _ = logfunc("$3")\n
        logFunc: function(funcName as string)
            ctx = getGlobalAA()
            ignoreLog = m._state.disableFuncLogger = true or ctx.disableLogFunc = true or m._isLocked() = true
            if ignoreLog then return __getFuncTrackerInterface({}, true)
            functionExitingIndicator = m._buildFuntionLog({
                _top: ctx.top
                funcName: funcName
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
        _doNothing: useMock
        _textFormatter: _getTextFromatter(indicatorNode.tab.len(), 14)

        ' @description formatted log that will be printed/cahced with correct indentation
        p: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")
            if m._doNothing then return m
            if not m.trackerNode.muted then
                text = m._textFormatter.proccesText(text, [_0, _1, _2, _3])
                ' text = substitute(text, _0, _1, _2, _3) ' old
                if not m.indicatorNode.printThroughFuncLogger
                    ?m.tab text
                else
                    funcLogger().log(m.tab + text, true)
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
    }
end function

' ======================================== GLOBAL PUBLIC FUNCTIONS =====================================


' @description same as `funcLogger().logFunc("...")`
' use it for log function call, and save returned value to variable
' example :
'   sub someFunc()
'       _ =  logfunc("someFunc")
'   end sub
function logFunc(funcName as string)
    return funcLogger().logFunc(funcName)
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

' @description will convert any variable to string if it possible.
' @param obj -  object that will be converted to string
' @param [_tab] - which indentation should be applied for converted object
function convertToStr(obj, _tab = 0, wrapStringInQuotes = false)
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
