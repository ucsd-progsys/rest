{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

module Language.REST.Types (
    prettyPrint
  , PPArgs(..)
  , Relation(..)
  , toOrderedSet
  ) where

import GHC.Generics (Generic)
import Prelude hiding (GT, EQ)

import           Data.Hashable
import qualified Data.List as L
import qualified Data.HashSet as S
import qualified Data.Set as OS
import qualified Data.Map as M
import qualified Data.Text as T
import           Text.Printf

import           Language.REST.Op
import           Language.REST.MetaTerm as MT
import           Language.REST.RuntimeTerm as MT

data PPArgs = PPArgs
  { ppReplace  :: [(T.Text, T.Text)]
  , ppInfixOps :: [(T.Text, T.Text)]
  , ppCustom   :: MetaTerm -> Maybe T.Text
  }

prettyPrint :: ToMetaTerm a => PPArgs -> a -> String
prettyPrint (PPArgs substs infixOps custom) t = T.unpack $ go $ replaceAll $ toMetaTerm t where

  replace s | Just (from, to) <- L.find ((`T.isPrefixOf` s) . fst) substs
            = T.append to $ T.drop (T.length from) s
  replace s | otherwise = s

  replaceAll :: MT.MetaTerm -> MT.MetaTerm
  replaceAll (MT.Var x)            = MT.Var x
  replaceAll (MT.RWApp (Op op) ts) = MT.RWApp (Op (replace op)) (map replaceAll ts)



  go :: MT.MetaTerm -> T.Text
  go (MT.Var x) = T.pack x
  go t | Just s <- custom t      = s
  go (MT.RWApp (Op op) [t1, t2]) | Just op' <- L.lookup op infixOps
    = T.pack $ printf "%s %s %s" (goParens t1) op' (goParens t2)
  go (MT.RWApp (Op op) [])       = op
  go (MT.RWApp (Op op) xs)       = T.concat [op, "(" , T.intercalate ", " (map go xs) , ")"]

  goParens t | needsParens t = T.pack $ printf "(%s)" (go t)
  goParens t | otherwise     = go t

  needsParens (MT.RWApp (Op op) _) = op `elem` (map fst infixOps)
  needsParens _                    = False

data Relation = GT | GTE | EQ deriving (Eq, Generic, Hashable)

instance Show Relation where
  show GT  = ">"
  show GTE = "≥"
  show EQ  = "≅"

instance Hashable a => Hashable (OS.Set a) where
  hashWithSalt i s = hashWithSalt i (OS.toList s)

instance (Hashable a, Hashable b) => Hashable (M.Map a b) where
  hashWithSalt i s = hashWithSalt i (M.toList s)

toOrderedSet :: (Eq a, Hashable a, Ord a) => S.HashSet a -> OS.Set a
toOrderedSet = OS.fromList . S.toList
