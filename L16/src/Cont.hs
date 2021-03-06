{-# LANGUAGE GeneralizedNewtypeDeriving #-}
-- RankNTypes, 
module Cont where
import Control.Applicative
import Control.Monad
import Control.Monad.Trans

-- A computation in the continuation monad gets its continuation
-- (what to do after it's done) as an argument.

newtype Cont r a = Cont { unCont :: (a -> r) -> r }
                   --   continuation ^^^^^^

instance Monad (Cont r) where
  return  =  returnC
  (>>=)   =  bindC

returnC :: a -> Cont r a
returnC a = Cont $ \k -> k a
                    
bindC :: Cont r a -> (a -> Cont r b) -> Cont r b
bindC m f = Cont $ \k -> unCont m $ \x -> unCont (f x) k

-- running is to continue by doing nothing (id)
runCont :: Cont a a -> a
runCont m = unCont m id

class Monad m => MonadCont m where
  -- callCC gives a computation access to its continuation. This
  -- continuation can be used to abort the computation (see
  -- example below).
  callCC :: ((a -> m b) -> m a) -> m a

instance MonadCont (Cont r) where
  -- callCC :: ((a -> Cont r b) -> Cont r a) -> Cont r a
  callCC f = Cont $ \k -> unCont (f (liftK k)) k
    where
      -- Lift the internal continuation to a computation.
      liftK :: (a -> r) -> a -> Cont r b
      liftK k x = Cont $ \_ -> k x

-- Example
example :: MonadCont m => Int -> m Int
example n = do
  x <- callCC $ \k -> do
         when (even n) (k 0) -- if n is even jump straight out of
                             -- callCC with x = 0
         return (n + 1)
  return x

-- The transformer version

-- Note that m doesn't have to be a monad for ContT r m to be a
-- monad.
newtype ContT r m a = ContT { unContT :: Cont (m r) a }
  deriving (Monad, MonadCont, Functor, Applicative)

runContT :: Monad m => ContT a m a -> m a
runContT m = unCont (unContT m) return

instance MonadTrans (ContT r) where
  lift m = ContT $ Cont $ \k -> m >>= k

instance MonadIO m => MonadIO (ContT r m) where
  liftIO = lift . liftIO

----------------
-- Some extras

instance Functor (Cont r) where
  fmap = fmapC

instance Applicative (Cont r) where
  pure = pureC
  (<*>) = apC

fmapC :: (a -> b) -> Cont r a -> Cont r b
fmapC f (Cont ga) = Cont $ \kb -> ga (kb . f)

pureC :: a -> Cont r a
pureC a = Cont $ \k -> k a
apC :: Cont r (a -> b) -> Cont r a -> Cont r b
apC (Cont gf) (Cont ga) = Cont $ \kb ->
                            ga $ \ka ->
                            gf $ \kf ->
                            kb (kf ka)
