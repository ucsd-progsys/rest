{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Language.REST.OCToAbstract where

import Data.Hashable
import Debug.Trace

import Control.Monad.Identity

import Language.REST.AbstractOC
import qualified Language.REST.OrderingConstraints as OC
import Language.REST.Types
import Language.REST.SMT

showHash :: Show a => a -> String
showHash = show . hash . show

lift :: forall impl base lifted m . (ToSMTVar base Int, Ord base, Eq base, Hashable base, Show lifted, Show base, Show (impl base)) =>
     OC.OrderingConstraints impl m
  -> OC.ConstraintGen impl base lifted Identity
  -> AbstractOC (impl base) lifted m
lift oc cgen =
  AbstractOC {
    isSat  = isSat'
  , top    = top'
  , refine = refine'
  , union  = OC.union oc
  , notStrongerThan = OC.notStrongerThan oc
  }
  where
    isSat' :: impl base -> m Bool
    isSat' aoc = OC.isSatisfiable oc aoc

    top' :: impl base
    top' = OC.noConstraints oc

    refine' :: impl base -> lifted -> lifted -> impl base
    refine' c t u =
      let
        msg = "Start refine " ++ (show t) ++ " >= " ++ (show u) ++ " from " ++ show c ++ "\n\n\n"
        pair = -- trace' msg $
          runIdentity $ cgen oc GTE top' t u
        result          = -- trace' ("Start intersect " ++ showHash pair ++ "\n\n\n with \n\n" ++ showHash c) $
          OC.intersect oc c pair
      in
        result

-- trace' _ x = x
trace' = trace
