sub init()
    
end sub
sub basicUsage()
    _ = logfunc("basicUsage") ' or funclogger().logFunction("basicUsage")
    _.p("print from basicUsage")
    _.xp("nobody will se me") ' won't be printed
    basicNested_1()
    foo_log()
end sub

sub basicNested_1()
    _ = logfunc("basicNested_1")
    _.p("print from foo_log {0}{1}", "it", "works")
    foo_log()
    ignored_foo_log()
end sub

sub foo_log()
    _ = xlogfunc("foo_log")
    _.p("print from foo_log")
end sub

sub ignored_foo_log()
    _ = xlogfunc("it won't be printed")
    _.p("this one also")
    _.xp("this too")
end sub