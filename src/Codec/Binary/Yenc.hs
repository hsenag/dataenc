-- |
-- Module    : Codec.Binary.Yenc
-- Copyright : (c) 2007 Magnus Therning
-- License   : BSD3
--
-- Implementation based on the specification found at
-- <http://yence.sourceforge.net/docs/protocol/version1_3_draft.html>.
--
-- Further documentation and information can be found at
-- <http://www.haskell.org/haskellwiki/Library/Data_encoding>.
module Codec.Binary.Yenc
    ( EncIncData(..)
    , EncIncRes(..)
    , encodeInc
    , encode
    , DecIncData(..)
    , DecIncRes(..)
    , decodeInc
    , decode
    , chop
    , unchop
    ) where

import Codec.Binary.Util

import Data.Word

_criticalsIn = [0xd6, 0xe0, 0xe3, 0x13]
_equal = 0x3d

-- {{{1 encode
data EncIncData = EChunk [Word8] | EDone
data EncIncRes = EPart [Word8] (EncIncData -> EncIncRes) | EFinal [Word8]

encodeInc e = eI e
    where
        enc [] = []
        enc (o:os)
            | o `elem` _criticalsIn = _equal : o + 106 : enc os
            | otherwise = o + 42 : enc os

        eI EDone = EFinal []
        eI (EChunk bs) = EPart (enc bs) encodeInc

-- | Encode data.
encode :: [Word8]
    -> [Word8]
encode bs = case encodeInc (EChunk bs) of
    EPart r1 f -> case f EDone of
        EFinal r2 -> r1 ++ r2

-- {{{1 decode
decodeInc :: DecIncData [Word8] -> DecIncRes [Word8]
decodeInc d = dI [] d
    where
        dI [] Done = Final [] []
        dI lo Done = Fail [] lo
        dI lo (Chunk s) = doDec [] (lo ++ s)
            where
                doDec acc (0x3d:d:ds) = doDec (acc ++ [d + 150]) ds
                doDec acc (d:ds) = doDec (acc ++ [d + 214]) ds
                doDec acc s' = Part acc (dI s')

-- | Decode data (strict).
decode :: [Word8]
    -> Maybe [Word8]
decode = decoder decodeInc

-- {{{1 chop
-- | Chop up a string in parts.
chop :: Int     -- ^ length of individual lines
    -> [Word8]
    -> [[Word8]]
chop _ [] = []
chop n ws = let
        _n = max n 1
        (p1, p2) = splitAt _n ws
    in
        if last p1 == _equal
            then (p1 ++ take 1 p2) : chop _n (drop 1 p2)
            else p1 : chop _n p2

-- {{{1 unchop
-- | Concatenate the strings into one long string.
unchop :: [[Word8]]
    -> [Word8]
unchop = concat
