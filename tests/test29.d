//T compiles:yes
//T retval:42
//T has-passed:no

enum A : byte
{
    Foo
}

enum B : long
{
    Bar
}

int main()
{
    if (A.Foo.sizeof < B.Bar.sizeof) {
        return 42;
    } else {
        return 0;
    }
}
