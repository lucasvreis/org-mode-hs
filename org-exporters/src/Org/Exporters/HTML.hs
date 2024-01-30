{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeFamilies #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Org.Exporters.HTML where

import Data.Map qualified as Map
import Org.Exporters.Common
import Org.Types.Variants.Annotated

defBackend :: Monad m => ExportBackend m
defBackend =
  let affiliatedMap kws =
        "affiliated" #% affAttrs
        where
          affAttrs :: [(Text, Text)]
          affAttrs = join $ mapMaybe getHtmlAttrs (Map.toList kws)
          getHtmlAttrs ("attr_html", BackendKeyword v) = Just v
          getHtmlAttrs ("name", ValueKeyword v) = Just [("id", v)]
          getHtmlAttrs _ = Nothing
      srcPretty _ _ _ = namespace pass
      babelCall _ = namespace pass
      macro _ _ = namespace pass
      customExp _ _ _ = Nothing
   in ExportBackend {..}
