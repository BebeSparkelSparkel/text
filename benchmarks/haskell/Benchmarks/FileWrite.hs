-- | Benchmarks simple file writing
--
-- Tested in this benchmark:
--
-- * Writing a file to the disk
--

{-# LANGUAGE BangPatterns #-}

module Benchmarks.FileWrite
    ( mkFileWriteBenchmarks
    ) where

import System.IO
import Data.String (fromString)
import qualified Data.Text.Lazy as LT
import Test.Tasty.Bench (Benchmark, bgroup, bench, nfAppIO)
import qualified Data.Text.IO as T
import qualified Data.Text.Lazy.IO as LT
import Control.DeepSeq (NFData, deepseq)
import Data.Functor ((<&>))
import Data.Text (StrictText)
import Data.Text.Lazy (LazyText)
import qualified Data.Text.IO.Utf8 as Utf8
import Data.Bifunctor (first)

mkFileWriteBenchmarks :: IO (Handle, IO ()) -> IO (Benchmark, IO ())
mkFileWriteBenchmarks mkSinkNRemove = do
  let writeDate = LT.cycle $ fromString [minBound..maxBound]
      lengths = [0..5] <> [10,20..100] <> [1000,10000,100000]
      testGroup :: NFData text => String -> (Handle -> text -> IO ()) -> ((StrictText,LazyText) -> text) -> Newline -> IO (Benchmark, IO ())
      testGroup groupName hPutStr select nl = do
        let nlm = NewlineMode nl nl
        (!noBufH, noBufRm) <- mkSinkNRemove
        hSetBuffering noBufH NoBuffering
        hSetNewlineMode noBufH nlm
        (!lineBufH, lineBufRm) <- mkSinkNRemove
        hSetBuffering lineBufH LineBuffering
        hSetNewlineMode lineBufH nlm
        (!blockBufH, blockBufRm) <- mkSinkNRemove
        hSetBuffering blockBufH $ BlockBuffering Nothing
        hSetNewlineMode blockBufH nlm

        return
          ( bgroup (groupName <> " " <> show nl) $ lengths <&> \n -> let
              st = LT.toStrict lt
              lt = LT.take n writeDate
              t = select (st, lt)
              in bgroup ("length " <> show n) $ deepseq t
                [ bench "NoBuffering"    $ nfAppIO (hPutStr noBufH)    t
                , bench "LineBuffering"  $ nfAppIO (hPutStr lineBufH)  t
                , bench "BlockBuffering" $ nfAppIO (hPutStr blockBufH) t
                ]
          , do
              noBufRm
              lineBufRm
              blockBufRm
          )
  first (bgroup "FileWrite")
    . foldr (\(b,r) (bs,rs) -> (b:bs,r>>rs)) ([], return ())
    <$> sequence
    [ testGroup "Strict hPutStr" T.hPutStr    strict LF
    , testGroup "Lazy   hPutStr" LT.hPutStr   lazy   LF
    , testGroup "Strict hPutStr" T.hPutStr    strict CRLF
    , testGroup "Lazy   hPutStr" LT.hPutStr   lazy   CRLF
    , testGroup "Utf-8  hPutStr" Utf8.hPutStr strict LF
    ]

strict = fst
lazy = snd