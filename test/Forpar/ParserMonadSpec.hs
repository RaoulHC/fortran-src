module Forpar.ParserMonadSpec where

import Forpar.ParserMonad
import Control.Monad.State.Lazy
import Test.Hspec

vanillaParseState :: ParseState String
vanillaParseState = ParseState { psAlexInput = "", psVersion = Fortran66, psFilename = "<unknown>" }

spec :: Spec
spec =
  describe "ParserMonad" $ do
    describe "Parse" $ do
      it "should give out correct version" $ do
        evalState getVersionP vanillaParseState `shouldBe` Fortran66

      it "satisfies read after write equals to what is written" $ do
        let ai = evalState (putAlexP "l'enfer" >> getAlexP) vanillaParseState in
          ai `shouldBe` "l'enfer"

    describe "Lex" $ do
      it "reads the state correctly" $ do
        runLex getAlexL vanillaParseState `shouldBe` ""

      it "overrides the state correctly" $ do
        let ai = runLex (putAlexL "c'est" >> getAlexL) vanillaParseState in
            ai `shouldBe` "c'est"

      it "mixes operations correctly" $ do
       let ai = runLex (putAlexL "hello" >> getAlexL >>= \s -> (putAlexL $ take 4 s) >> getAlexL) vanillaParseState in
             ai `shouldBe` "hell"
