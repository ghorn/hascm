{-# OPTIONS_GHC -Wall #-}

module Main where

import Hascm.Vectorize
import Hascm.TypeNats
import Hascm.TypeVecs ( Vec(..), mkVec' )
import Hascm.Nlp
import Hascm.StaticNlp
import Hascm.Sqp

buildRosen :: IO (Nlp (Vec D2) None (Vec D0))
buildRosen = fmap fst $ buildNlp $ do
  
  x <- designVar "position"
  y <- designVar "y"
  
  minimize $ (1-x)**2 + 100 * (y - x**2)**2


main :: IO ()
main = do
  rosen <- buildRosen

  let x0 = [-8,8]
  
  (SqpIn xopt _ _ _, _, kktInf) <- solveSqp rosen (mkVec' x0 :: Vec D2 Double) None
  print xopt
  print kktInf