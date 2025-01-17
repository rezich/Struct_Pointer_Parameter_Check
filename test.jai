Foo :: struct { bar: int; }

// Maybe-by-reference
a :: (foo: Foo) { // OK
}
b :: (foo: Foo) { // OK
    x := foo;
}

// By pointer
pa :: (foo: *Foo) { // Report
}
pb :: (foo: *Foo) { // OK
    foo = null;
}
pc :: (foo: *Foo) { // Report
    a(foo);
}
pd :: (foo: *Foo) { // OK
    foo.bar = 42;
}
pe :: (foo: *Foo) { // OK
    global_foo_pointer = foo;
}
pf :: (foo: *Foo) { // OK
    local_foo_pointer := foo;
    pb(local_foo_pointer);
}
pg :: (foo: *Foo) { // OK
    local_bar := foo.bar;
}
ph :: (foo: *Foo) { // OK
    local_bar := 42 + foo.bar;
}
pi :: (foo: *Foo) { // OK
    local_foo := foo.*;
}
pj :: (foo: *Foo) { // Report (TODO)
    i(foo.bar);
}

ua :: (using foo: Foo) { // OK
}
ub :: (using foo: Foo) { // OK
    local_bar := bar;
}
uc :: (using foo: Foo) { // OK
    local_bar := i(bar);
}

/*upa :: (using foo: *Foo) { // Report (TODO)
}*/

i :: (n: int) {}

global_foo_pointer: *Foo;

main :: () {}
#import "Basic";
