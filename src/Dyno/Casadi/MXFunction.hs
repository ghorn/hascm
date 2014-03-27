{-# OPTIONS_GHC -Wall -fno-cse -fno-warn-orphans #-}

module Dyno.Casadi.MXFunction
       ( C.MXFunction, mxFunction, callMX, evalDMatrix
       ) where

import Data.Vector ( Vector )
import qualified Data.Vector as V
import System.IO.Unsafe ( unsafePerformIO )
import Control.Monad ( zipWithM_ )

import qualified Casadi.Wrappers.Classes.MXFunction as C
import qualified Casadi.Wrappers.Classes.IOInterfaceFX as C
import qualified Casadi.Wrappers.Classes.FX as C

import Dyno.Casadi.MX ( MX )
import Dyno.Casadi.DMatrix ( DMatrix )

mxFunction :: Vector MX -> Vector MX -> IO C.MXFunction
mxFunction inputs outputs = C.mxFunction'' inputs outputs
{-# NOINLINE mxFunction #-}

-- | call an MXFunction on symbolic inputs, getting symbolic outputs
callMX :: C.FXClass f => f -> Vector MX -> Vector MX
callMX f ins = unsafePerformIO (C.fx_call'''''''' f ins)
{-# NOINLINE callMX #-}

-- | evaluate an MXFunction with 1 input and 1 output
evalDMatrix :: (C.FXClass f, C.IOInterfaceFXClass f) => f -> Vector DMatrix -> IO (Vector DMatrix)
evalDMatrix mxf inputs = do
  -- set inputs
  zipWithM_ (C.ioInterfaceFX_setInput'''''' mxf) (V.toList inputs) [0..]

  -- eval
  C.fx_evaluate mxf

  -- get outputs
  numOut <- C.ioInterfaceFX_getNumOutputs mxf
  outputs <- mapM (C.ioInterfaceFX_output mxf) (take numOut [0..])

  -- return vectorized outputs
  return (V.fromList outputs)
