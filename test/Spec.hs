{-# OPTIONS_GHC -O -fplugin Test.Inspection.Plugin #-}
{-# OPTIONS_GHC -dsuppress-all #-}

{-# LANGUAGE AllowAmbiguousTypes             #-}
{-# LANGUAGE DataKinds                       #-}
{-# LANGUAGE DeriveGeneric                   #-}
{-# LANGUAGE DuplicateRecordFields           #-}
{-# LANGUAGE ExistentialQuantification       #-}
{-# LANGUAGE RankNTypes                      #-}
{-# LANGUAGE ScopedTypeVariables             #-}
{-# LANGUAGE TypeApplications                #-}
{-# LANGUAGE TemplateHaskell                 #-}

module Main where

import GHC.Generics
import Data.Generics.Product
import Data.Generics.Sum
import Test.Inspection
import Test.HUnit
import Util
import System.Exit
import Data.Generics.Internal.VL.Lens
import Data.Generics.Internal.VL.Prism
import Data.Generics.Internal.VL.Traversal

-- This is sufficient at we only want to test that they typecheck
import Test24 ()
import Test25 ()

main :: IO ()
main = do
  res <- runTestTT tests
  case errors res + failures res of
    0 -> exitSuccess
    _ -> exitFailure

data Record = MkRecord
  { fieldA :: Int
  , fieldB :: Bool
  } deriving Generic

data Record2 = MkRecord2
  { fieldA :: Int
  } deriving Generic

data Record3 a = MkRecord3
  { fieldA :: a
  , fieldB :: Bool
  } deriving (Generic, Show)

data Record4 a = MkRecord4
  { fieldA :: a
  , fieldB :: a
  } deriving (Generic1)

data Record5 = MkRecord5
  { fieldA :: Int
  , fieldB :: Int
  , fieldC :: String
  , fieldD :: Int
  , fieldE :: Char
  , fieldF :: Int
  } deriving Generic



typeChangingManual :: Lens (Record3 a) (Record3 b) a b
typeChangingManual f (MkRecord3 a b) = (\a' -> MkRecord3 a' b) <$> f a

typeChangingManualCompose :: Lens (Record3 (Record3 a)) (Record3 (Record3 b)) a b
typeChangingManualCompose = typeChangingManual . typeChangingManual

newtype L s a = L (Lens' s a)

intTraversalManual :: Traversal' Record5 Int
intTraversalManual f (MkRecord5 a b c d e f') =
    pure (\a1 a2 a3 a4 -> MkRecord5 a1 a2 c a3 e a4) <*> f a <*> f b <*> f d <*> f f'

intTraversalDerived :: Traversal' Record5 Int
intTraversalDerived = types

fieldALensManual :: Lens' Record Int
fieldALensManual f (MkRecord a b) = (\a' -> MkRecord a' b) <$> f a

subtypeLensManual :: Lens' Record Record2
subtypeLensManual f record
  = fmap (\ds -> case record of
                  MkRecord _ b -> MkRecord (case ds of {MkRecord2 g1 -> g1}) b
         ) (f (MkRecord2 (case record of {MkRecord a _ -> a})))

data Sum1 = A Char | B Int | C () | D () deriving (Generic, Show)
data Sum2 = A2 Char | B2 Int deriving (Generic, Show)

sum1PrismManual :: Prism Sum1 Sum1 Int Int
sum1PrismManual eta = prism g f eta
 where
   f s1 = case s1 of
            B i -> Right i
            s   -> Left s
   g = B

sum1PrismManualChar :: Prism Sum1 Sum1 Char Char
sum1PrismManualChar eta = prism g f eta
 where
   f s1 = case s1 of
            A i -> Right i
            B _ -> Left s1
            C _ -> Left s1
            D _ -> Left s1
   g = A

sum2PrismManual :: Prism Sum2 Sum2 Int Int
sum2PrismManual eta = prism g f eta
 where
   f s1 = case s1 of
            B2 i -> Right i
            s   -> Left s
   g = B2


sum2PrismManualChar :: Prism Sum2 Sum2 Char Char
sum2PrismManualChar eta = prism g f eta
 where
   f s1 = case s1 of
            A2 i -> Right i
            s   -> Left s
   g = A2

-- Note we don't have a catch-all case because of #14684
subtypePrismManual :: Prism Sum1 Sum1 Sum2 Sum2
subtypePrismManual eta = prism g f eta
  where
    f s1 = case s1 of
             A c -> Right (A2 c)
             B i -> Right (B2 i)
             C _   -> Left s1
             D _   -> Left s1
    g (A2 c) = A c
    g (B2 i) = B i


--------------------------------------------------------------------------------
-- * Tests
-- The inspection-testing plugin checks that the following equalities hold, by
-- checking that the LHSs and the RHSs are CSEd. This also means that the
-- runtime characteristics of the derived lenses is the same as the manually
-- written ones above.

fieldALensName :: Lens' Record Int
fieldALensName = field @"fieldA"

fieldALensType :: Lens' Record Int
fieldALensType = typed @Int

fieldALensPos :: Lens' Record Int
fieldALensPos = position @1

subtypeLensGeneric :: Lens' Record Record2
subtypeLensGeneric = super

typeChangingGeneric :: Lens (Record3 a) (Record3 b) a b
typeChangingGeneric = field @"fieldA"

typeChangingGenericPos :: Lens (Record3 a) (Record3 b) a b
typeChangingGenericPos = position @1

typeChangingGenericCompose :: Lens (Record3 (Record3 a)) (Record3 (Record3 b)) a b
typeChangingGenericCompose = field @"fieldA" . field @"fieldA"

sum1PrismB :: Prism Sum1 Sum1 Int Int
sum1PrismB = _Ctor @"B"

subtypePrismGeneric :: Prism Sum1 Sum1 Sum2 Sum2
subtypePrismGeneric = _Sub

sum1TypePrism :: Prism Sum1 Sum1 Int Int
sum1TypePrism = _Typed @Int

sum1TypePrismChar :: Prism Sum1 Sum1 Char Char
sum1TypePrismChar = _Typed @Char

sum2TypePrism :: Prism Sum2 Sum2 Int Int
sum2TypePrism = _Typed @Int

sum2TypePrismChar :: Prism Sum2 Sum2 Char Char
sum2TypePrismChar = _Typed @Char

tests :: Test
tests = TestList $ map mkHUnitTest
  [ $(inspectTest $ 'fieldALensManual === 'fieldALensName)
  , $(inspectTest $ 'fieldALensManual === 'fieldALensType)
  , $(inspectTest $ 'fieldALensManual === 'fieldALensPos)
  , $(inspectTest $ 'subtypeLensManual === 'subtypeLensGeneric)
  , $(inspectTest $ 'typeChangingManual === 'typeChangingGeneric)
  , $(inspectTest $ 'typeChangingManual === 'typeChangingGenericPos)
  , $(inspectTest $ 'typeChangingManualCompose === 'typeChangingGenericCompose)
  , $(inspectTest $ 'intTraversalManual === 'intTraversalDerived)
  , $(inspectTest $ 'sum1PrismManual === 'sum1PrismB)
  , $(inspectTest $ 'subtypePrismManual === 'subtypePrismGeneric)
  , $(inspectTest $ 'sum2PrismManualChar === 'sum2TypePrismChar)
  , $(inspectTest $ 'sum2PrismManual === 'sum2TypePrism)
  , $(inspectTest $ 'sum1PrismManualChar === 'sum1TypePrismChar)
  , $(inspectTest $ 'sum2PrismManualChar === 'sum2TypePrismChar)
  , $(inspectTest $ 'sum1PrismManual === 'sum1TypePrism) ]
