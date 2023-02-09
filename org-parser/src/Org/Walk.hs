{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Org.Walk
  ( module Org.Walk,
    MultiWalk,
    (.>),
    (?>)
  )
where

import Control.MultiWalk
import Control.MultiWalk.Contains
import Org.Types

data MWTag

type Walk = Control.MultiWalk.Walk MWTag Identity

type WalkM m = Control.MultiWalk.Walk MWTag m

type Query m = Control.MultiWalk.Query MWTag m

query :: (MultiWalk MWTag c, MultiWalk MWTag t, Monoid m) => (t -> m) -> c -> m
query = Control.MultiWalk.query @MWTag

walkM :: (MultiWalk MWTag c, MultiWalk MWTag t, Monad m) => (t -> m t) -> c -> m c
walkM = Control.MultiWalk.walkM @MWTag

walk :: (MultiWalk MWTag c, MultiWalk MWTag t) => (t -> t) -> c -> c
walk = Control.MultiWalk.walk @MWTag

buildMultiQ ::
  (MultiWalk MWTag a, Monoid m) =>
  (Org.Walk.Query m -> QList m (MultiTypes MWTag) -> QList m (MultiTypes MWTag)) ->
  a ->
  m
buildMultiQ = Control.MultiWalk.buildMultiQ @MWTag

buildMultiW ::
  (MultiWalk MWTag a, Applicative m) =>
  (Org.Walk.WalkM m -> FList m (MultiTypes MWTag) -> FList m (MultiTypes MWTag)) ->
  a ->
  m a
buildMultiW = Control.MultiWalk.buildMultiW @MWTag

instance MultiTag MWTag where
  type
    MultiTypes MWTag =
      '[ OrgDocument,
         OrgSection,
         -- Element stuff
         OrgElement,
         ListItem,
         -- Object stuff
         OrgObject,
         Citation
       ]
  type SubTag MWTag = MWTag

type List a = Trav [] a

type DoubleList a = MatchWith [[a]] (Trav (Compose [] []) a)

instance MultiSub MWTag OrgDocument where
  type SubTypes MWTag OrgDocument = ToSpecList '[List OrgElement, List OrgSection]

instance MultiSub MWTag OrgElement where
  type
    SubTypes MWTag OrgElement =
      ToSpecList
        '[ List OrgElement,
           List OrgObject,
           Trav (Map Text) (Under KeywordValue (List OrgObject)), -- Objects under affiliated keywords
           Under KeywordValue (List OrgObject), -- Objects under keywords
           List ListItem,
           List (Under TableRow (DoubleList OrgObject)), -- Objects under table rows
           DoubleList OrgObject -- Objects under verse blocks
         ]

instance MultiSub MWTag ListItem where
  type
    SubTypes MWTag ListItem =
      ToSpecList
        '[ List OrgObject,
           List OrgElement
         ]

instance MultiSub MWTag OrgSection where
  type
    SubTypes MWTag OrgSection =
      ToSpecList
        '[List OrgObject, List OrgElement, List OrgSection]

instance MultiSub MWTag OrgObject where
  type
    SubTypes MWTag OrgObject =
      ToSpecList
        '[ List OrgObject,
           Under FootnoteRefData (List OrgElement),
           Citation
         ]

instance MultiSub MWTag Citation where
  type
    SubTypes MWTag Citation =
      ToSpecList
        '[ List OrgObject,
           List (Under CiteReference (List OrgObject))
         ]
