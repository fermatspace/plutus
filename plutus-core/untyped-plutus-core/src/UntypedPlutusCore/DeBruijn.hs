{-# LANGUAGE DerivingStrategies    #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
-- | Support for using de Bruijn indices for term names.
module UntypedPlutusCore.DeBruijn
    ( Index (..)
    , DeBruijn (..)
    , NamedDeBruijn (..)
    , FreeVariableError (..)
    , AsFreeVariableError (..)
    , deBruijnTerm
    , deBruijnProgram
    , unDeBruijnTerm
    , unDeBruijnProgram
    , unNameDeBruijn
    , fakeNameDeBruijn
    ) where

import PlutusCore.DeBruijn.Internal

import PlutusCore.Name
import PlutusCore.Quote
import UntypedPlutusCore.Core

import Control.Lens hiding (Index, index)
import Control.Monad.Except
import Control.Monad.Reader

import Data.Bimap qualified as BM

{- Note [Comparison with typed deBruijn conversion]
This module is just a boring port of the typed version.
-}

-- | Convert a 'Term' with 'TyName's and 'Name's into a 'Term' with 'TyDeBruijn's and 'DeBruijn's.
deBruijnTerm
    :: (AsFreeVariableError e, MonadError e m)
    => Term Name uni fun ann -> m (Term NamedDeBruijn uni fun ann)
deBruijnTerm = flip runReaderT (Levels 0 BM.empty) . deBruijnTermM

-- | Convert a 'Program' with 'TyName's and 'Name's into a 'Program' with 'TyDeBruijn's and 'DeBruijn's.
deBruijnProgram
    :: (AsFreeVariableError e, MonadError e m)
    => Program Name uni fun ann -> m (Program NamedDeBruijn uni fun ann)
deBruijnProgram (Program ann ver term) = Program ann ver <$> deBruijnTerm term

deBruijnTermM
    :: (MonadReader Levels m, AsFreeVariableError e, MonadError e m)
    => Term Name uni fun ann
    -> m (Term NamedDeBruijn uni fun ann)
deBruijnTermM = \case
    -- variable case
    Var ann n -> Var ann <$> nameToDeBruijn n
    -- binder cases
    LamAbs ann n t -> declareUnique n $ do
        n' <- nameToDeBruijn n
        withScope $ LamAbs ann n' <$> deBruijnTermM t
    -- boring recursive cases
    Apply ann t1 t2 -> Apply ann <$> deBruijnTermM t1 <*> deBruijnTermM t2
    Delay ann t -> Delay ann <$> deBruijnTermM t
    Force ann t -> Force ann <$> deBruijnTermM t
    Prod ann es -> Prod ann <$> traverse deBruijnTermM es
    Proj ann i p -> Proj ann i <$> deBruijnTermM p
    Tag ann i p -> Tag ann i <$> deBruijnTermM p
    Case ann arg cs -> Case ann <$> deBruijnTermM arg <*> traverse deBruijnTermM cs
    -- boring non-recursive cases
    Constant ann con -> pure $ Constant ann con
    Builtin ann bn -> pure $ Builtin ann bn
    Error ann -> pure $ Error ann

-- | Convert a 'Term' with 'TyDeBruijn's and 'DeBruijn's into a 'Term' with 'TyName's and 'Name's.
unDeBruijnTerm
    :: (MonadQuote m, AsFreeVariableError e, MonadError e m)
    => Term NamedDeBruijn uni fun ann -> m (Term Name uni fun ann)
unDeBruijnTerm = flip runReaderT (Levels 0 BM.empty) . unDeBruijnTermM

-- | Convert a 'Program' with 'TyDeBruijn's and 'DeBruijn's into a 'Program' with 'TyName's and 'Name's.
unDeBruijnProgram
    :: (MonadQuote m, AsFreeVariableError e, MonadError e m)
    => Program NamedDeBruijn uni fun ann -> m (Program Name uni fun ann)
unDeBruijnProgram (Program ann ver term) = Program ann ver <$> unDeBruijnTerm term

unDeBruijnTermM
    :: (MonadReader Levels m, MonadQuote m, AsFreeVariableError e, MonadError e m)
    => Term NamedDeBruijn uni fun ann
    -> m (Term Name uni fun ann)
unDeBruijnTermM = \case
    -- variable case
    Var ann n -> Var ann <$> deBruijnToName n
    -- binder cases
    LamAbs ann n t ->
        -- See NOTE: [DeBruijn indices of Binders]
        declareBinder $ do
            n' <- deBruijnToName $ set index 0 n
            withScope $ LamAbs ann n' <$> unDeBruijnTermM t
    -- boring recursive cases
    Apply ann t1 t2 -> Apply ann <$> unDeBruijnTermM t1 <*> unDeBruijnTermM t2
    Delay ann t -> Delay ann <$> unDeBruijnTermM t
    Force ann t -> Force ann <$> unDeBruijnTermM t
    Prod ann es -> Prod ann <$> traverse unDeBruijnTermM es
    Proj ann i p -> Proj ann i <$> unDeBruijnTermM p
    Tag ann i p -> Tag ann i <$> unDeBruijnTermM p
    Case ann arg cs -> Case ann <$> unDeBruijnTermM arg <*> traverse unDeBruijnTermM cs
    -- boring non-recursive cases
    Constant ann con -> pure $ Constant ann con
    Builtin ann bn -> pure $ Builtin ann bn
    Error ann -> pure $ Error ann
