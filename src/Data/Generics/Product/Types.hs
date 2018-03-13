{-# LANGUAGE AllowAmbiguousTypes   #-}
{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE DefaultSignatures     #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds             #-}
{-# LANGUAGE Rank2Types            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Generics.Product.Types
-- Copyright   :  (C) 2017 Csongor Kiss
-- License     :  BSD3
-- Maintainer  :  Csongor Kiss <kiss.csongor.kiss@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable
--
-- Derive traversals of a given type in a product.
--
-----------------------------------------------------------------------------

module Data.Generics.Product.Types
  ( -- *Traversals
    --
    --  $example
    HasTypes (..)
  ) where

import Data.Kind

import GHC.Generics
import Data.Generics.Internal.VL.Traversal
import Data.Generics.Product.Constraints

class HasTypes a s where
  types :: Traversal' s a

  default types :: Traversal' s a
  types _ = pure
  {-# INLINE types #-}

-- instance
--   ( Hastypes' (Interesting s a) a s
--   ) => HasTypes a s where
--   types = types' @(Interesting s a)
--   {-# INLINE types #-}

instance HasTypesC a a s s => HasTypes a s where
  types = typesC

--class Hastypes' (t :: Bool) a s where
--  types' :: Traversal' s a
--
--instance
--  ( GHasTypes a (Rep s)
--  , Generic s
--  ) => Hastypes' 'True a s where
--  types' f s = to <$> gtypes f (from s)
--  --{-# INLINE types' #-}
--
--instance Hastypes' 'False a s where
--  types' _ = pure
--  --{-# INLINE types' #-}
--
--instance {-# OVERLAPPING #-} HasTypes a Bool
--instance {-# OVERLAPPING #-} HasTypes a Char
--instance {-# OVERLAPPING #-} HasTypes a Double
--instance {-# OVERLAPPING #-} HasTypes a Float
--instance {-# OVERLAPPING #-} HasTypes a Int
--instance {-# OVERLAPPING #-} HasTypes a Integer
--instance {-# OVERLAPPING #-} HasTypes a Ordering

--------------------------------------------------------------------------------
class HasTypesC a b s t where
  typesC :: Traversal s t a b

instance
  ( HasTypesC' (Interesting s a) a b s t
  ) => HasTypesC a b s t where
  typesC = typesC' @(Interesting s a)
  {-# INLINE typesC #-}

instance {-# OVERLAPPING #-} HasTypesC a b a b where
  typesC f s = f s
  {-# INLINE typesC #-}

-- instance {-# OVERLAPS #-} c ~ Int => HasTypesC a b Int c where
--   typesC _ = pure
--   {-# INLINE typesC #-}

--instance {-# OVERLAPPING #-} HasTypesC a b Char Char where
--  typesC _ = pure
--  {-# INLINE typesC #-}
--
--instance {-# OVERLAPPING #-} HasTypesC a b Double Double where
--  typesC _ = pure
--  {-# INLINE typesC #-}
--
--instance {-# OVERLAPPING #-} HasTypesC a b Float Float where
--  typesC _ = pure
--  {-# INLINE typesC #-}
--
--instance {-# OVERLAPPING #-} HasTypesC a b Integer Integer where
--  typesC _ = pure
--  {-# INLINE typesC #-}

class HasTypesC' (i :: Bool) a b s t where
  typesC' :: Traversal s t a b

instance
  ( Generic s
  , Generic t
  , HasConstraints (HasTypesC a b) s t
  ) => HasTypesC' 'True a b s t where
  typesC' f s = constraints @(HasTypesC a b) (typesC @a @b f) s
  {-# INLINE typesC' #-}

instance HasTypesC' 'False a b s s where
  typesC' _ = pure
  {-# INLINE typesC' #-}

--------------------------------------------------------------------------------

class GHasTypes a s where
  gtypes :: Traversal' (s x) a

instance
  ( GHasTypes a l
  , GHasTypes a r
  ) => GHasTypes a (l :*: r) where
  gtypes f (l :*: r) = (:*:) <$> gtypes f l <*> gtypes f r
  {-# INLINE gtypes #-}

instance
  ( GHasTypes a l
  , GHasTypes a r
  ) => GHasTypes a (l :+: r) where
  gtypes f (L1 l) = L1 <$> gtypes f l
  gtypes f (R1 r) = R1 <$> gtypes f r
  {-# INLINE gtypes #-}

instance (GHasTypes a s) => GHasTypes a (M1 m meta s) where
  gtypes f (M1 s) = M1 <$> gtypes f s
  {-# INLINE gtypes #-}

instance {-# OVERLAPPING #-} GHasTypes a (Rec0 a) where
  gtypes f (K1 x) = K1 <$> f x
  {-# INLINE gtypes #-}

instance HasTypes a b => GHasTypes a (Rec0 b) where
  gtypes f (K1 x) = K1 <$> types @a f x
  {-# INLINE gtypes #-}

instance GHasTypes a U1 where
  gtypes _ _ = pure U1
  {-# INLINE gtypes #-}

instance GHasTypes a V1 where
  gtypes _ = pure
  {-# INLINE gtypes #-}

type family HackRep a where
  HackRep Char = Rec0 Char
  HackRep Double = Rec0 Double
  HackRep Float = Rec0 Float
  HackRep Int = Rec0 Int
  HackRep Integer = Rec0 Integer
  HackRep a = Rep a

type Interesting f a = Snd (Interesting' (HackRep f) a '[f])

type family Interesting' f (a :: Type) (seen :: [Type]) :: ([Type], Bool) where
  Interesting' (M1 _ m f) t seen
    = Interesting' f t seen
  -- The result of the left branch is passed on to the right branch in order to avoid duplicate work
  Interesting' (l :*: r) t seen
    = InterestingOr (Interesting' l t seen) r t
  Interesting' (l :+: r) t seen
    = InterestingOr (Interesting' l t seen) r t
  Interesting' (Rec0 t) t seen
    = '(seen, 'True)
  Interesting' (Rec0 Char)     _ seen = '(seen ,'False)
  Interesting' (Rec0 Double)   _ seen = '(seen ,'False)
  Interesting' (Rec0 Float)    _ seen = '(seen ,'False)
  Interesting' (Rec0 Int)      _ seen = '(seen ,'False)
  Interesting' (Rec0 Integer)  _ seen = '(seen ,'False)
  Interesting' (Rec0 r) t seen
    = InterestingUnless (Elem r seen) (Rep r) t r seen
  Interesting' _ _ seen
    = '(seen, 'False)

-- Short circuit
-- Note: we only insert 'r' to the seen list if it's not already there (which is precisely when `s` is 'False)
type family InterestingUnless (s :: Bool) f (a :: Type) (r :: Type) (seen :: [Type]) :: ([Type], Bool) where
  InterestingUnless 'True _ _ _ seen = '(seen, 'False)
  InterestingUnless 'False f a r seen = Interesting' f a (r ': seen)

-- Short circuit
type family InterestingOr (b :: ([Type], Bool)) r t :: ([Type], Bool) where
  InterestingOr '(seen, 'True) _ _ = '(seen, 'True)
  InterestingOr '(seen, 'False) r t = Interesting' r t seen

type family Elem a as where
  Elem a (a ': _) = 'True
  Elem a (_ ': as) = Elem a as
  Elem a '[] = 'False

type family Snd a where
  Snd '(_, b) = b

