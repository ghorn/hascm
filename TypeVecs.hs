{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeFamilies #-}

--{-# LANGUAGE MultiParamTypeClasses #-}
--{-# LANGUAGE FlexibleInstances #-}
--{-# LANGUAGE FlexibleContexts #-}
--{-# LANGUAGE UndecidableInstances #-}
--{-# LANGUAGE TypeOperators #-}
--{-# LANGUAGE ScopedTypeVariables #-}

module TypeVecs
       ( Vec ( unSeq )
       , unVec
       , tvlength
       , tvlengthT
       , (<++>)
       , (|>)
       , (<|)
       , mkSeq
       , mkVec
       , unsafeSeq
       , unsafeVec
       , tvsplitAt
       , tvhead
       , tvzipWith
       , tvinit
       , tvtail
       , tvlast
       , tvreplicate
       , tvconcatMap
       , tvempty
       , tvsingleton
       , tvindex
       , tvsplitsAt
       )
       where

import Data.Foldable ( Foldable )
import Data.Traversable ( Traversable )
import qualified Data.Foldable as F
import qualified Data.Sequence as S
import qualified Data.Vector as V

import GHC.Generics ( Generic1 )

import TypeNats

-- length-indexed vectors using phantom types
newtype Vec n a = MkVec {unSeq :: S.Seq a} deriving (Eq, Ord, Functor, Foldable, Traversable, Generic1)

unVec :: Vec n a -> V.Vector a
unVec = V.fromList . F.toList . unSeq

infixr 5 <|
infixl 5 |>
(<|) :: a -> Vec n a -> Vec (Succ n) a
(<|) x xs = MkVec $ x S.<| (unSeq xs)

(|>) :: Vec n a -> a -> Vec (Succ n) a
(|>) xs x = MkVec $ (unSeq xs) S.|> x

-- create a Vec with a runtime check
unsafeVec :: (IntegerT n) => V.Vector a -> Vec n a
unsafeVec = unsafeSeq . S.fromList . V.toList

unsafeSeq :: (IntegerT n) => S.Seq a -> Vec n a
unsafeSeq xs = case MkVec xs of
  ret -> let staticLen = tvlength ret
             dynLen = S.length xs
         in if staticLen == dynLen
            then ret
            else error $ "unsafeVec: static/dynamic length mismatch: " ++
                 "static: " ++ show staticLen ++ ", dynamic: " ++ show  dynLen

mkVec :: V.Vector a -> Vec n a
mkVec = MkVec . S.fromList . V.toList
--mkVec = unsafeVec -- lets just run the check every time for now

mkSeq :: S.Seq a -> Vec n a
mkSeq = MkVec
--mkSeq = unsafeSeq -- lets just run the check every time for now

--mkVec :: (IntegerT n) => V.Vector a -> Vec n a
--mkVec = unsafeVec -- lets just run the check every time for now

--mkSeq :: (IntegerT n) => S.Seq a -> Vec n a
--mkSeq = unsafeSeq -- lets just run the check every time for now

tvlength :: IntegerT n => Vec n a -> Int
tvlength = fromIntegerT . (undefined `asLengthOf`)

tvlengthT :: Vec n a -> n
tvlengthT = (undefined `asLengthOf`)

asLengthOf :: n -> Vec n a -> n
asLengthOf x _ = x

---- split into two
tvsplitAt :: (IntegerT i
              --(i :<=: n) ~ True
              ) =>
             i -> Vec (i :+: n) a -> (Vec i a, Vec n a)
tvsplitAt i v = (mkSeq x, mkSeq y)
  where
    (x,y) = S.splitAt (fromIntegerT i) (unSeq v)

tvzipWith :: (IntegerT n) => (a -> b -> c) -> Vec n a -> Vec n b -> Vec n c
tvzipWith f x y = mkSeq (S.zipWith f (unSeq x) (unSeq y))

tvempty :: Vec D0 a
tvempty = mkSeq S.empty

tvsingleton :: a -> Vec D1 a
tvsingleton = mkSeq . S.singleton

tvindex :: (IntegerT i,
            IntegerT n,
            (i :<=: n) ~ True) => i -> Vec n a -> a
tvindex k v = S.index (unSeq v) (fromIntegerT k)

tvhead :: (PositiveT n) => Vec n a -> a
tvhead x = case S.viewl (unSeq x) of
  y S.:< _ -> y
  S.EmptyL -> error "vhead: empty"

tvtail :: (NaturalT n) => Vec (Succ n) a -> Vec n a
tvtail x = case S.viewl (unSeq x) of
  _ S.:< ys -> mkSeq ys
  S.EmptyL -> error "vtail: empty"

tvinit :: (NaturalT n) => Vec (Succ n) a -> Vec n a
tvinit x = case S.viewr (unSeq x) of
  ys S.:> _ -> mkSeq ys
  S.EmptyR -> error "vinit: empty"

tvlast :: (PositiveT n) => Vec n a -> a
tvlast x = case S.viewr (unSeq x) of
  _ S.:> y -> y
  S.EmptyR -> error "vlast: empty"

tvreplicate :: (IntegerT n) => n -> a -> Vec n a
tvreplicate n = mkSeq . (S.replicate (fromIntegerT n))

tvconcatMap :: (a -> Vec n b) -> Vec m a -> Vec (n :*: m) b
tvconcatMap f = mkVec . (V.concatMap (unVec . f)) . unVec

-- concatenate two vectors
infixr 5 <++>
(<++>) :: Vec n1 a -> Vec n2 a -> Vec (n1 :+: n2) a
(<++>) x y = mkSeq $ (unSeq x) S.>< (unSeq y)


-- break a vector jOuter vectors, each of length kInner
splitsAt' :: (IntegerT kInner) => kInner -> Int -> S.Seq a -> [Vec kInner a]
splitsAt' kInner jOuter v
  | kInner' == 0 =
    if S.null v
    then replicate jOuter (mkSeq S.empty)
    else error $ "splitsAt 0 " ++ show jOuter ++ ": got non-zero vector"
  | jOuter == 0 =
      if S.null v
      then []
      else error $ "splitsAt " ++ show kInner' ++ " 0: leftover vector of length: " ++ show (S.length v)
  | kv0 < kInner' =
    error $ "splitsAt " ++ show kInner' ++ " " ++ show jOuter ++ ": " ++ "ran out of vector input"
  | otherwise = mkSeq v0 : splitsAt' kInner (jOuter - 1) v1
  where
    kv0 = S.length v0
    (v0,v1) = S.splitAt kInner' v
    kInner' = fromIntegerT kInner :: Int
--    jOuter' = fromIntegerT jOuter :: Int


-- break a vector jOuter vectors, each of length kFixed
tvsplitsAt :: (IntegerT kInner, IntegerT jOuter) =>
              kInner -> jOuter -> Vec (kInner :*: jOuter) a -> Vec jOuter (Vec kInner a)
tvsplitsAt k j vs = mkSeq (S.fromList x)
  where
    --x :: [Vec kInner a]
    x = splitsAt' k (fromIntegerT j) (unSeq vs)


instance Show a => Show (Vec n a) where
  showsPrec _ = showV . F.toList . unSeq
    where
      showV []      = showString "<>"
      showV (x:xs)  = showChar '<' . shows x . showl xs
        where
          showl []      = showChar '>'
          showl (y:ys)  = showChar ',' . shows y . showl ys
