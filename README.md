# FuncLogger
small logger for brightscript which can calculate indentation for current call's stack
Check out `output` and `components/SceneRoot.brs` files to see more examle of usage.

### Note:
We cannot automatically update call stack after functions executions because there is no way to have destructors aka in c++. But we can detect whether the logged function is executed or not. I would name it as lazy destructors :D

## Getting Started
### Install 
Just copy `/source/utilities/FuncLogger.brs` file to your project and add script for needed component.
Or you can copy code from file above to you utility file.
### How to use it
Just call `logFunc("name of some function")` and save returned value as local variable (see example). 
Example:
```
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
```
Output:
```
 --> SceneRoot::basicUsage
    print from basicUsage
     --> SceneRoot::basicNested_1
        print from foo_log it works
         --> SceneRoot::foo_log
            print from foo_log
     --> SceneRoot::foo_log
        print from foo_log
```
## API
### Global Functions
#### `funcLogger() as object`
Returns instance of `FuncLogger`. Also each call `funcLogger()` will update and save current call stack.

#### `logFunc(funcName as string)`
Makes log with passed function name.
same as `funcLogger().logFunc("function name")`
Parameters:
* `funcName as string` - name of function that will be logged

Return value:
* function tracker object that has interface for work with created log

#### `xlogFunc(funcName as string)`
Use it for skip particular log

#### `lockcomponent(value = true as boolean)`
Will permanently lock funcLogger for current component.
All calls to `logFunc` will be ignored.

#### `unlockComponent()`
Will permanently unlock funcLogger for current component.

#### `convertToStr(obj, _tab = 0)`
Will convert any variable to string if it possible

Parameters:
* obj - object that will be converted to string
* _tab - (oprional) which indentation should be applied for converted object

### FuncLogger object
#### FuncLogger settings
##### `cachingMode: "none"`
Possible values:
* `"none"` - relatime output.
* `"full"` - will cache all logs. 
* `"short"` - will cache logs only for current call stack. Each time when stack size reaches 0, logs will be cleared.

##### `printOffset: 4`
Aka how many whitespaces use for tab.

##### `disableFuncLogger: false`
Set as `true` to disable FuncLogger

##### `printComponentType: true`
If `true` will print component type (`m.top.subtype()`).

##### `printComponentID: false`
If `true` will print component id.

##### `printCallContext: false`
If `true` will print name of parent function

##### `printCallTime: false`
If `true` will print time when function was called. 
With next format ` minutes:seconds.milliseconds`

##### `measureExecTime: false`
If `true` will print execution time of function.
NOTE: it is inaccurate, and requires additional call `funcLogger()` after function executes.

#### FuncLogger methods
##### `getOffset: function () as integer`
Returns current offset according to call's stack

##### `disable: function(isDisabled as boolean)`
Will permanently disable/enable funcLogger

##### `log: sub(text as string, ignoreIndentation = false)`
Makes print that will be printed/cahced with correct indentation

Parameters:
* `ignoreIndentation = false` - optional, determines whether `text` will be printed with current indentation

##### `logf: sub(text as object, args = [], ignoreIndentation = false)`
Makes formatted print and call `m.log` under hood.

Parameters:
* `text` - string that will be formatted and passed to `m.log`
* `args = []` - an array of args that will be used for substitution in `text`
* `ignoreIndentation = false` - optional, determines whether `text` will be printed with current indentation

##### `printLogs: sub()`
Will print out all cached logs

##### `logFunc: function(funcName as string)`
Makes log with passed function name.
same as global `logFunc("function name")`
Parameters:
* `funcName as string` - name of function that will be logged

Return value:
* function tracker object that has interface for work with created log

##### `xlogFunc: function(funcName as string)`
Use it for skip particular log

##### `saveState: sub()`
will update current state of global field, where we store state

### Function Tracker methods
#### `p: function (text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")`
Formatted log print will be printed/cahced with correct indentation for current function log.

#### `xp: sub(text = "" as string, _0 = "", _1 = "", _2 = "", _3 = "")`
Skipped print

#### `mute: function(isMute = true as boolean) as object`
Will mute all prints for current function

#### `muteChildren: function(isMute = true as boolean) as object`
Will mute prints in all nested functions

#### `muteAll: function(isMute = true as boolean) as object`
Will mute all prints for current function and nested functions

#### `lockChildren: function(value = true as boolean) as object`
Will temporarily lock funcLogger for nested functions. Unlocks after function executes

#### `plock: function(value = true as boolean) as object`
Will permanently lock funcLogger for current component.
Same as `lockcomponent()`

#### `tlock: function(value = true as boolean) as object`
will temporarily lock funcLogger for current component. Unlocks after function executes

