module WebDriver.Internal exposing (Test(..), ErrorLevel(..), duplicatedName, unwrap, failNow, Command(..), Parsed(..))

import Task exposing (Task)
import WebDriver.LowLevel.Value exposing (Answer)
import WebDriver.LowLevel.Functions exposing (Functions)
import Set exposing (Set)


type Test
    = UnitTest (Functions -> Task ( ErrorLevel, String ) Answer)
      -- | FuzzTest (Random.Seed -> Int -> List Expectation)
    | Labeled String Test
    | Skipped Test
    | Only Test
    | Batch (List Test)
    | ParseError String


type ErrorLevel
    = StopOne
    | StopAll


failNow : String -> Test
failNow description =
    ParseError description


duplicatedName : List Test -> Result String (Set String)
duplicatedName =
    let
        names : Test -> List String
        names test =
            case test of
                Labeled str _ ->
                    [ str ]

                Batch subtests ->
                    List.concatMap names subtests

                UnitTest _ ->
                    []

                ParseError _ ->
                    []

                -- FuzzTest _ ->
                -- []
                Skipped subTest ->
                    names subTest

                Only subTest ->
                    names subTest

        insertOrFail : String -> Result String (Set String) -> Result String (Set String)
        insertOrFail newName =
            Result.andThen
                (\oldNames ->
                    if Set.member newName oldNames then
                        Err newName
                    else
                        Ok <| Set.insert newName oldNames
                )
    in
        List.concatMap names
            >> List.foldl insertOrFail (Ok Set.empty)


type Command
    = TextMe Bool Bool String
    | DoMe Bool Bool String (Functions -> Task ( ErrorLevel, String ) Answer)


type Parsed
    = Success Bool (List Command)
    | Error String


unwrap : Test -> Parsed
unwrap current =
    unwrapFold False False 0 current (Success False [])


unwrapFold : Bool -> Bool -> Int -> Test -> Parsed -> Parsed
unwrapFold skiping only offset_ current acc_ =
    let
        offset =
            (offset_ + 2)

        offsetString =
            String.repeat offset_ " "
    in
        case ( current, acc_ ) of
            ( _, Error a ) ->
                acc_

            ( UnitTest test, Success onlyMode acc ) ->
                DoMe skiping only (offsetString) test :: acc |> Success onlyMode

            ( Labeled string data, Success onlyMode acc ) ->
                TextMe skiping only (offsetString ++ string)
                    :: acc
                    |> Success onlyMode
                    |> unwrapFold skiping only offset data

            ( ParseError string, Success onlyMode acc ) ->
                Error string

            ( Skipped data, Success onlyMode acc ) ->
                case (unwrapFold True only offset data (Success onlyMode [])) of
                    Success onlyMode a ->
                        a ++ acc |> Success onlyMode

                    Error result ->
                        Error result

            ( Only data, Success onlyMode acc ) ->
                case (unwrapFold skiping True offset data (Success True [])) of
                    Success onlyMode a ->
                        a ++ acc |> Success True

                    Error result ->
                        Error result

            ( Batch listData, Success onlyMode acc ) ->
                case listData |> List.foldl (\i acc2 -> unwrapFold skiping only offset_ i acc2) (Success onlyMode []) of
                    Success onlyMode a ->
                        a ++ acc |> Success onlyMode

                    Error result ->
                        Error result
