module WebDriver.Test exposing (Test, describe, only, skip, test)

{-|

@docs Test,test, describe, skip, only

-}

import Set
import Task exposing (Task)
import WebDriver.Internal as Internal
import WebDriver.Step as Step exposing (Functions)


{-| A test which has yet to be evaluated. When evaluated,
it produces one or more scenarios execution agains [`WebDriver`](https://w3c.github.io/webdriver/) host

See [`test`](#test) for some ways to create a `Test`.

-}
type alias Test =
    Internal.Test


{-| Returns a [`Test`](#Test) that causes other tests to be skipped, and only runs the given one.

Calls to `only` aren't meant to be committed to version control. Instead, use
them when you want to focus on getting a particular subset of your tests to pass.
If you use `only`, your entire test suite will fail, even if
each of the individual tests pass. This is to help avoid accidentally
committing a `only` to version control.

If you use `only` on multiple tests, only those tests will run. If you
put a `only` inside another `only`, only the outermost `only`
will affect which tests gets run.

See also [`skip`](#skip). Note that `skip` takes precedence over `only`;
if you use a `skip` inside an `only`, it will still get skipped, and if you use
an `only` inside a `skip`, it will also get skipped.

    import WebDriver.Test exposing (describe, only, skip)
    import Task

    describe "WebDriver"
        [ describe "Navigate"
            [ test "this test will not be executed" <|
                \_ -> Task.succeed ()
             only <| test "this test will be executed" <|
                \_ -> Task.succeed ()
            ]
        ]

-}
only : Test -> Test
only =
    Internal.Only


{-| Returns a [`Test`](#Test) that gets skipped.

Calls to `skip` aren't meant to be committed to version control. Instead, use
it when you want to focus on getting a particular subset of your tests to
pass. If you use `skip`, your entire test suite will fail, even if
each of the individual tests pass. This is to help avoid accidentally
committing a `skip` to version control.

See also [`only`](#only). Note that `skip` takes precedence over `only`;
if you use a `skip` inside an `only`, it will still get skipped, and if you use
an `only` inside a `skip`, it will also get skipped.

    import WebDriver.Test exposing (describe, test, skip)
    import Task

    describe "WebDriver"
        [ describe "Navigate"
            [ skip <| test "this test will not be executed" <|
                \_ -> Task.succeed ()
             test "this test will be executed" <|
                \_ -> Task.succeed ()
            ]
        ]

-}
skip : Test -> Test
skip =
    Internal.Skipped


{-| Return a [`Test`](#Test) that evaluates a single
scenario agains [`WebDriver`](https://w3c.github.io/webdriver/) host.

    import Test exposing (test)
    import Expect
    test "go to github main page" <|
        \{ url } ->
            url "https://github.com"

-}
test : String -> (Functions -> Task String out) -> Test
test untrimmedDesc thunk =
    let
        desc =
            String.trim untrimmedDesc
    in
    thunk
        >> Task.andThen (\_ -> Task.succeed Internal.Pass)
        >> Task.onError (Internal.Fail False >> Task.succeed)
        |> Internal.UnitTest
        |> Internal.Labeled desc


{-| Apply a description to a list of tests.

    import WebDriver.Test exposing (describe, test)


    describe "WebDriver"
        [ describe "Navigate"
            [ test "go to github main page" <|
                \{ url } ->
                    url "https://github.com"
            ]
        ]

Passing an empty list will result in a failing test, because you either made a
mistake or are creating a placeholder.

-}
describe : String -> List Test -> Test
describe untrimmedDesc tests =
    let
        desc =
            String.trim untrimmedDesc
    in
    if String.isEmpty desc then
        Internal.failNow
            "This `describe` has a blank description. Let's give it a useful one!"
    else if List.isEmpty tests then
        Internal.failNow
            ("This `describe " ++ desc ++ "` has no tests in it. Let's give it some!")
    else
        case Internal.duplicatedName tests of
            Err duped ->
                Internal.failNow
                    ("The tests '" ++ desc ++ "' contain multiple tests named '" ++ duped ++ "'. Let's rename them so we know which is which.")

            Ok childrenNames ->
                if Set.member desc childrenNames then
                    Internal.failNow
                        ("The test '" ++ desc ++ "' contains a child test of the same name. Let's rename them so we know which is which.")
                else
                    Internal.Labeled desc (Internal.Batch tests)
