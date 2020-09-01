function init()
    m.top.setFocus(true)
    m.myLabel = m.top.findNode("myLabel")
    m.myLabel.font.size=92
    m.myLabel.color="0x72D7EEFF"

    testFuncLogger()
end function

sub testFuncLogger()
  functions = [
      basicUsage, 
      basicUsage_mute, basicUsage_muteChildren, basicUsage_muteAll, 
      basicUsage_lockChildren, basicUsage_plock, basicUsage_tlock, 
      funcLogger_GoodMeasureExec, funcLogger_BadMeasureExec, 
      funcLogger_full_cachingMode, funcLogger_short_cachingMode
  ]

  default_state = {
      cachingMode: "none" ' "none" - relatime output, "full" - will collect all logs, "short" will collect logs only for current call stack
      printOffset: 4
      disableFuncLogger: false
      printComponentType: true
      printComponentID: false
      printCallContext: false
      printCallTime: false
      measureExecTime: false 
  }
  
  ?""
  ?"------------------------ run usage examples -------------------------"
  ?""
  
  for each func in functions
      logger = funcLogger()
      logger._state.append(default_state)
      logger.saveState()
      unlockcomponent()  

      func()
      
      funcLogger()' will clear call stack
      ?chr(10) "----" chr(10)
  end for

  ?""
  ?"------------------------ run settings permutations -------------------------"
  ?""

  settingsForChange = ["printCallContext", "printComponentType", "printComponentID", "printCallTime", "measureExecTime"]
  permutationGenerator = getPermutationGenerator(settingsForChange.count(), [false, true])

  settingsPermutation = permutationGenerator.getPermutation()
  while settingsPermutation <> invalid
      i = 0
      printCurrentSettings = []
      for each field in settingsForChange
          funcLoggerState_setValue(field, settingsPermutation[i])  
          printCurrentSettings.push("    "  + field + ": " + settingsPermutation[i].toStr())
          i++
      end for

      ?chr(10) "============ set current func logger settings as [" 
      ?printCurrentSettings.join(chr(10)) 
      ?"]" chr(10) ""
      
      basicUsage()

      settingsPermutation = permutationGenerator.getPermutation()
  end while 
end sub

'//------------------- "full" cachingMode mode
sub funcLogger_full_cachingMode()' as none mode, but all logs will be cached
  funcLoggerState_setValue("cachingMode", "full")    
  _ = logfunc("funcLogger_full_cachingMode")
  foo_log()
  _.p("text 1")
  ?"    text 2 // always will be printed"
  _.p("text 3")
 funcLogger().printLogs() ' if you do not call `funcLogger().printLogs()` "text 1", "text 3" "funcLogger_full_cachingMode" won't be printed
end sub

'//------------------- "short" cachingMode mode
sub funcLogger_short_cachingMode()' as full mode, but only logs from current stack will be cached
  funcLoggerState_setValue("cachingMode", "short")
  basicUsage()
  ' on this line call stack will be empty, so logs will be empty too
  _ = logfunc("funcLogger_short_cachingMode")
  _.p("print from funcLogger_short_cachingMode") 
  foo_log()
  funcLogger().printLogs() ' if you do not call `funcLogger().printLogs()` nothing will be printed
end sub

'//------------------ tlock  
sub basicUsage_tlock() ' temporary local lock of current component
  _ = logfunc("basicUsage_tlock").tlock()
  _.p("print from basicUsage_tlock") ' will be printed
  basicUsage() ' everything will be ignored cuz it is in same component
  createObject("roSGNode", "FooComponent").callFunc("basicUsage") ' will be logged cuz it is in non-locked component
  _ = invalid ' means that execution basicUsage_tlock has ended and component will automatically unlocks 
  foo_log() ' will be logged 
end sub

'//------------------- plock
sub basicUsage_plock() ' permament local lock of current component
  _ = logfunc("basicUsage_plock").plock() ' or you can just call `lockComponent()`
  ' **WARNIGN** after this component will be locked until you mannualy call _.plock(false) or unlockComponent() or lockComponent(false)
  _.p("print from basicUsage_plock") ' will be printed
  basicUsage() ' everything will be ignored cuz it is in same component
  createObject("roSGNode", "FooComponent").callFunc("basicUsage") ' will be logged cuz it is in non-locked component
end sub

'//------------------- lock children
sub basicUsage_lockChildren() ' temporary global lock
  _ = logfunc("basicUsage_lockChildren").lockChildren()
  _.p("print from basicUsage_lockChildren") ' will be printed
  basicUsage() ' all nested `logfunc` and prints will be ignored
end sub

'//------------------- mute all
sub basicUsage_muteAll()
  _ = logfunc("basicUsage_muteAll").muteAll()
  _.p("print from basicUsage_muteAll") ' will be ignored
  basicUsage() ' all `_.p("some usefull text")` in nested function will be ignored
end sub

sub basicUsage_muteChildren()
  _ = logfunc("basicUsage_muteChildren").muteChildren()
  _.p("print from basicUsage_muteChildren") ' will be printed
  basicUsage() ' but all _.p("some usefull text") in nested function will be ignored
end sub

sub basicUsage_mute()
  _ = logfunc("basicUsage_mute").mute()
  _.p("print from basicUsage_mute") ' will be ignored
  basicUsage()
end sub

'//------------------- basic
sub basicUsage()
  _ = logfunc("basicUsage") ' or funclogger().logFunc("basicUsage")
  _.p("print from basicUsage")
  _.xp("nobody will se me") ' won't be printed
  basicNested_1()
  foo_log()
end sub

sub basicNested_1()
  _ = logfunc("basicNested_1")
  _.p("print from foo_log {0} {1}", "it", "works")
  foo_log()
  ignored_foo_log()
end sub

sub foo_log()
  _ = logfunc("foo_log")
  _.p("print from foo_log")
end sub

sub ignored_foo_log()
  _ = xlogfunc("it won't be printed")
  _.p("this one also")
  _.xp("this too")
end sub

'//------------------- with enabled measureExecTime: true
sub funcLoggerState_setValue(field as string, value)
  logger = funcLogger()
  logger._state[field] = value
  logger.saveState()
end sub

sub funcLogger_GoodMeasureExec()
  funcLoggerState_setValue("measureExecTime", true)
  _ = logfunc("funcLogger_GoodMeasureExec")
  sleep(100)
  nestedMesureExec()
  funclogger() ' will update call stack which detect that nestedMesureExec has ended
  sleep(100)

  _ = invalid ' means that execution funcLogger_GoodMeasureExec has ended
  funcLogger() ' cuz we has lazy destrucot should mannualy update call stack
end sub

sub funcLogger_BadMeasureExec()
  funcLoggerState_setValue("measureExecTime", true)
  _ = logfunc("funcLogger_BadMeasureExec")
  sleep(100)
  nestedMesureExec()
  'funclogger() ' will update call stack which detect that nestedMesureExec has ended
  sleep(100)

  _ = invalid ' means that execution funcLogger_BadMeasureExec has ended
  funcLogger() ' cuz we has lazy destrucot should mannualy update call stack
end sub

sub nestedMesureExec()
  _ = logfunc("nestedMesureExec")
  sleep(500)
end sub


function getPermutationGenerator(count as integer, values as object)
  _permutationGenerator = {
      values: []
      arr: []
      _count: 0
      index: 0
      needGetNext: false
      _findInArray: function(val , arr)
          for i = 0 to arr.count() -1 
              if arr[i] = val then return i
          end for
          return invalid
      end function 
      reset: sub()
          m.arr = []
          for i = 0 to m._count
              m.arr[i] =  m.values[0]
          end for
          m.index = 0
          m.needGetNext = false
      end sub
      init: sub(count, values)
          m._count = count-1 
          m.values = values
          m.reset()
      end sub
      getPermutation: function()
          while m.index < m.arr.count()
              if not m.needGetNext then 
                  m.needGetNext = true
                  return m.arr
              end if
              while m.index < m.arr.count()
                  valueIndex = m._findInArray(m.arr[m.index], m.values)
                  m.arr[m.index] = m.values[valueIndex+1] ' get next val
                  if m.arr[m.index] = invalid ' means we set maximum possible value 
                      m.arr[m.index] = m.values[0]
                      m.index += 1
                  else 
                      m.index = 0
                      exit while 
                  end if
              end while 
              m.needGetNext = false
          end while 
          return invalid
      end function
  }
  _permutationGenerator.init(count, values)
  return _permutationGenerator
end function