-- | A "readable" Agda-like way to pretty-print Untyped Plutus Core terms.

{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE UndecidableInstances  #-}

module UntypedPlutusCore.Core.Instance.Pretty.Readable () where

import PlutusPrelude

import UntypedPlutusCore.Core.Type

import PlutusCore.Core.Instance.Pretty.Common ()
import PlutusCore.Pretty.PrettyConst
import PlutusCore.Pretty.Readable (Direction (ToTheRight), PrettyConfigReadable, PrettyReadableBy, binderFixity,
                                   botFixity, compoundDocM, inContextM, juxtFixity, juxtPrettyM, prettyM, sequenceDocM,
                                   unitDocM)

import Prettyprinter
import Universe

instance
        ( PrettyReadableBy configName name
        , GShow uni, Closed uni, uni `Everywhere` PrettyConst, Pretty fun
        ) => PrettyBy (PrettyConfigReadable configName) (Term name uni fun a) where
    prettyBy = inContextM $ \case
        Constant _ val -> unitDocM $ pretty val
        Builtin _ bi -> unitDocM $ pretty bi
        Var _ name -> prettyM name
        LamAbs _ name body ->
            compoundDocM binderFixity $ \prettyIn ->
                let prettyBot x = prettyIn ToTheRight botFixity x
                in "\\" <> prettyBot name <+> "->" <+> prettyBot body
        Apply _ fun arg -> fun `juxtPrettyM` arg
        Delay _ term ->
            sequenceDocM ToTheRight juxtFixity $ \prettyEl ->
                "delay" <+> prettyEl term
        Force _ term ->
            sequenceDocM ToTheRight juxtFixity $ \prettyEl ->
                "force" <+> prettyEl term
        Error _ -> unitDocM "error"
        Prod _ es -> unitDocM "prod"
        Proj _ i p -> unitDocM "proj"
        Tag{} -> unitDocM "tag"
        Case{} -> unitDocM "case"

instance PrettyReadableBy configName (Term name uni fun a) =>
        PrettyBy (PrettyConfigReadable configName) (Program name uni fun a) where
    prettyBy = inContextM $ \(Program _ version term) ->
        sequenceDocM ToTheRight juxtFixity $ \prettyEl ->
            "program" <+> pretty version <+> prettyEl term
