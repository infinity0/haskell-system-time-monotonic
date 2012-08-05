-- |
-- Module:      System.Time.Monotonic
-- Copyright:   (c) Joseph Adams 2012
-- License:     BSD3
-- Maintainer:  joeyadams3.14159@gmail.com
-- Portability: Tested on Linux and Windows.
{-# LANGUAGE ExistentialQuantification #-}
module System.Time.Monotonic (
    -- * Clock
    Clock,
    newClock,
    clockGetTime,

    -- * Utilities
    threadDelayDiffTime,
) where

import System.Time.Monotonic.Direct

import Data.IORef
import Data.Time.Clock  (DiffTime)

------------------------------------------------------------------------
-- Clock

data Clock = forall time. Clock !(SystemClock time) !(IORef (ClockData time))

-- We can't have the Eq instance because the time type is existentially
-- quantified, meaning the equality below would have to compare two IORefs of
-- different value type.  If we really wanted it, we could add a dummy IORef,
-- use Typeable, or perhaps even use unsafeCoerce.
--
-- instance Eq Clock where
--     Clock _ a == Clock _ b = a == b

-- | The externally reported time, paired with the return value of
-- 'systemClockGetTime' at a given point in time.
data ClockData time = ClockData !DiffTime !time

-- | Create a new 'Clock'.
newClock :: IO Clock
newClock = do
    ssc <- getSystemClock
    case ssc of
        SomeSystemClock clock -> do
            st <- systemClockGetTime clock
            ref <- newIORef (ClockData 0 st)
            return (Clock clock ref)

-- | Return the amount of time that has elapsed since the clock was created
-- with 'newClock'.
clockGetTime :: Clock -> IO DiffTime
clockGetTime (Clock clock ref) = do
    st2 <- systemClockGetTime clock
    t2 <- atomicModifyIORef ref $
        \(ClockData t1 st1) ->
            let t2 = t1 + systemClockDiffTime clock st2 st1
             in (ClockData t2 st2, t2)
    t2 `seq` return t2

-- | Variant of 'threadDelay' for 'DiffTime'.  This takes care of overflow.
threadDelayDiffTime :: DiffTime -> IO ()
threadDelayDiffTime = undefined

{-
threadDelayMSec (MSec msec)
    | msec <= 0       = return ()
    | msec <= maxWait = wait msec
    | otherwise       = wait maxWait
                     >> threadDelayMSec (MSec (msec - maxWait))
  where
    -- maxWait is 100 seconds.  2^31-1 microseconds is about 2147 seconds.
    -- This gives the implementation of 'threadDelay' plenty of leeway if it
    -- needs to do some arithmetic on the time value first.
    maxWait = 100000
    wait    = threadDelay . (* 1000) . fromIntegral
-}
