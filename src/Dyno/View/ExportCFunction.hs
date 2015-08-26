{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE RankNTypes #-}

module Dyno.View.ExportCFunction
       ( CExportOptions(..)
       , exportCFunction
       , exportCFunction'
       ) where

import Data.Char ( toUpper )
import Text.Printf ( printf )

import Accessors ( Lookup )
import Casadi.Function ( generateCode )
import Casadi.MX ( MX )
import Dyno.Vectorize ( Vectorize, fill )

import Dyno.View.ExportCStruct
import Dyno.View.Fun
import Dyno.View.JV ( JV, catJV', splitJV' )
import Dyno.View.View ( J )

data CExportOptions =
  CExportOptions
  { expand :: Bool
  , generateMain :: Bool
  , exportName :: String
  }

exportCFunction ::
  forall f g
  . (Vectorize f, Vectorize g, Lookup (f Double), Lookup (g Double))
  => (J (JV f) MX -> J (JV g) MX) -> CExportOptions -> IO (String, String)
exportCFunction userFun options = do
  let ((fname, gname), typedefs) = runCStructExporter $ do
        fname' <- putStruct (fill 0 :: f Double)
        gname' <- putStruct (fill 0 :: g Double)
        return (fname', gname')

  mxfun <- toMXFun "userCodegenFun" userFun
  Fun fun <- if expand options then fmap toFun (expandMXFun mxfun) else return (toFun mxfun)
  let funName = exportName options
      header =
        unlines
        [ printf "#ifndef %s_H_" (map toUpper funName)
        , printf "#define %s_H_" (map toUpper funName)
        , ""
        , "/* This wrapper was automatically generated by dynobud. */"
        , ""
        , typedefs
        , ""
        , "#ifdef __cplusplus"
        , "extern \"C\" {"
        , "#endif"
        , ""
        , printf "  void %s(const %s* input, %s* output);" funName fname gname
        , ""
        , "#ifdef __cplusplus"
        , "extern \"C\" }"
        , "#endif"
        , ""
        , printf "#endif // %s_H_" (map toUpper funName)
        ]

      source =
        unlines
        [ generateCode fun (generateMain options)
        , ""
        , "/* The following wrapper was automaticaly generated by dynobud. */"
        , ""
        , printf "#include \"%s.h\"" funName
        , ""
        , printf "void %s(const %s* input, %s* output) {" funName fname gname
        , "  evaluate(input, output);"
        , "}"
        ]
  return (source, header)

-- convenience function which wraps a Floating type
exportCFunction' ::
  forall f g
  . (Vectorize f, Vectorize g, Lookup (f Double), Lookup (g Double))
  => (forall a . Floating a => f a -> g a) -> CExportOptions -> IO (String, String)
exportCFunction' userFun = exportCFunction (catJV' . userFun . splitJV')
