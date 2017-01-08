{-# language TypeFamilies, MultiParamTypeClasses, KindSignatures, FlexibleContexts, FlexibleInstances #-}
{-# language AllowAmbiguousTypes #-}
{-# language CPP #-}
module Numeric.LinearAlgebra.Class where

-- import Control.Applicative
import Data.Complex
-- import Data.Ratio
-- import Foreign.C.Types (CSChar, CInt, CShort, CLong, CLLong, CIntMax, CFloat, CDouble)

import qualified Data.Vector as V (Vector)

import Data.VectorSpace hiding (magnitude)

import Data.Sparse.Types
import Numeric.Eps





-- * Matrix and vector elements (possibly Complex)
class (Eq e , Fractional e) => Elt e where
  conj :: e -> e
  conj = id
instance Elt Double
instance Elt Float
instance RealFloat e => Elt (Complex e) where
  conj = conjugate
  

-- * Additive group

zero :: AdditiveGroup v => v
zero = zeroV
negated :: AdditiveGroup v => v -> v
negated = negateV




-- * Vector space
(.*) :: VectorSpace v => Scalar v -> v -> v
(.*) = (*^)

(./) :: (VectorSpace v, Fractional (Scalar v)) => v -> Scalar v -> v
v ./ n = recip n .* v

-- | Convex combination of two vectors (NB: 0 <= `a` <= 1). 
-- lerp :: (VectorSpace e, Num (Scalar e)) => Scalar e -> e -> e -> e
-- lerp a u v = a .* u ^+^ ((1-a) .* v)


-- linearCombination :: (VectorSpace v , Foldable t) => t (Scalar v, v) -> v
-- linearCombination  =  foldr (\(a, x) (b, y) -> (a .* x) ^+^ (b .* y)) 






-- * Hilbert space (inner product)

dot :: InnerSpace v => v -> v -> Scalar v
dot = (<.>)
  





-- ** Hilbert-space distance function
-- |`hilbertDistSq x y = || x - y ||^2`
hilbertDistSq :: InnerSpace v => v -> v -> Scalar v
hilbertDistSq x y = t <.> t where
  t = x ^-^ y








-- * Normed vector spaces

class InnerSpace v => Normed v where
  type Magnitude v :: *
  type RealScalar v :: *
  norm1 :: v -> Magnitude v      -- ^ L1 norm
  norm2Sq :: v -> Magnitude v    -- ^ Euclidean (L2) norm
  normP :: RealScalar v -> v -> Magnitude v -- ^ Lp norm (p > 0)
  normalize :: RealScalar v -> v -> v  -- ^ Normalize w.r.t. Lp norm
  normalize2 :: v -> v     -- ^ Normalize w.r.t. L2 norm



-- | Lift a real number onto the complex plane
toC :: Num a => a -> Complex a
toC r = r :+ 0



-- ** Norms and related results

-- |Euclidean norm
norm2 :: (Normed v, Floating (Magnitude v)) => v -> Magnitude v
norm2 x = sqrt (norm2Sq x)




-- | Infinity-norm (Real)
normInftyR :: (Foldable t, Ord a) => t a -> a
normInftyR x = maximum x

-- | Infinity-norm (Complex)
normInftyC :: (Foldable t, RealFloat a, Functor t) => t (Complex a) -> a
normInftyC x = maximum (magnitude <$> x)





instance Normed Double where
  type Magnitude Double = Double
  type RealScalar Double = Double
  norm1 = abs
  norm2Sq = abs
  normP _ = abs

instance Normed (Complex Double) where
  type Magnitude (Complex Double) = Double
  type RealScalar (Complex Double) = Double
  norm1 (r :+ i) = abs r + abs i
  norm2Sq = (**2) . magnitude
  -- normP p (r :+ i) = (r**p + i**p)**(1/p)
  











-- | Lp inner product (p > 0)
dotLp :: (Set t, Foldable t, Floating a) => a -> t a -> t a ->  a
dotLp p v1 v2 = sum u**(1/p) where
  f a b = (a*b)**p
  u = liftI2 f v1 v2


-- | Reciprocal
reciprocal :: (Functor f, Fractional b) => f b -> f b
reciprocal = fmap recip


-- |Scale
scale :: (Num b, Functor f) => b -> f b -> f b
scale n = fmap (* n)





-- * Linear vector space

class VectorSpace v => LinearVectorSpace v where
  type MatrixType v :: *
  (#>) :: MatrixType v -> v -> v
  (<#) :: v -> MatrixType v -> v
  -- matVec :: MatrixType v -> v -> v
  -- vecMat :: v -> MatrixType v -> v

-- (#> ):: LinearVectorSpace v => MatrixType v -> v -> v
-- (#>) = matVec

-- (<# ):: LinearVectorSpace v => v -> MatrixType v -> v
-- (<#) = vecMat
  






-- * Matrix ring

-- | A matrix ring is any collection of matrices over some ring R that form a ring under matrix addition and matrix multiplication

class AdditiveGroup m => MatrixRing m where
  type MatrixNorm m :: *
  (##) :: m -> m -> m
  transpose :: m -> m
  normFrobenius :: m -> MatrixNorm m


--

-- class MatrixRing (m :: * -> *) a where
--   type Matrix m a :: *
--   (##) :: Matrix m a -> Matrix m a -> Matrix m a
--   transpose :: Matrix m a -> Matrix m a
--   normFrobenius :: Matrix m a -> a


--

-- class (Num a, AdditiveGroup (m a)) => MatrixRing (m :: * -> *) a where
--   type Matrix m a :: *
--   (##) :: Matrix m a -> Matrix m a -> Matrix m a
--   transpose :: Matrix m a -> Matrix m a
--   normFrobenius :: Matrix m a -> a


-- class MatrixRing m a => SparseMatrixRing m a where
--   (#~#) :: Epsilon a => Matrix m a -> Matrix m a -> Matrix m a










-- * FiniteDim : finite-dimensional objects

class Functor f => FiniteDim f where
  type FDSize f :: *
  dim :: f a -> FDSize f


-- | unary dimension-checking bracket
withDim :: (FiniteDim f, Show s) =>
     f e
     -> (FDSize f -> f e -> Bool)
     -> (f e -> c)
     -> String
     -> (f e -> s)
     -> c
withDim x p f e ef | p (dim x) x = f x
                   | otherwise = error e' where e' = e ++ show (ef x)

-- | binary dimension-checking bracket
withDim2 :: (FiniteDim f, FiniteDim g, Show s) =>
     f e
     -> g e
     -> (FDSize f -> FDSize g -> f e -> g e -> Bool)
     -> (f e -> g e -> c)
     -> String
     -> (f e -> g e -> s)
     -> c
withDim2 x y p f e ef | p (dim x) (dim y) x y = f x y
                      | otherwise = error e' where e' = e ++ show (ef x y)






-- * HasData : accessing inner data (do not export)

class HasData f a where
  type HDData f a :: *
  nnz :: f a -> Int
  dat :: f a -> HDData f a


-- * Sparse : sparse datastructures

class (FiniteDim f, HasData f a) => Sparse f a where
  spy :: Fractional b => f a -> b




-- * Set : types that behave as sets

class Functor f => Set f where
  -- |union binary lift : apply function on _union_ of two "sets"
  liftU2 :: (a -> a -> a) -> f a -> f a -> f a

  -- |intersection binary lift : apply function on _intersection_ of two "sets"
  liftI2 :: (a -> a -> b) -> f a -> f a -> f b





class Sparse c a => SpContainer c a where
  type ScIx c :: *
  scInsert :: ScIx c -> a -> c a -> c a
  scLookup :: c a -> ScIx c -> Maybe a
  scToList :: c a -> [a]
  -- -- | Lookup with default, infix form ("safe" : should throw an exception if lookup is outside matrix bounds)
  (@@) :: c a -> ScIx c -> a









-- * SparseVector

class SpContainer v e => SparseVector v e where
  type SpvIx v :: *
  svFromList :: Int -> [(SpvIx v, e)] -> v e
  svFromListDense :: Int -> [e] -> v e
  svConcat :: Foldable t => t (v e) -> v e
  -- svZipWith :: (e -> e -> e) -> v e -> v e -> v e

-- * SparseMatrix

class SpContainer m e => SparseMatrix m e where
  smFromVector :: LexOrd -> (Int, Int) -> V.Vector (IxRow, IxCol, e) -> m e
  -- smFromFoldableDense :: Foldable t => t e -> m e  
  smTranspose :: m e -> m e
  -- smExtractSubmatrix ::
  --   m e -> (IxRow, IxRow) -> (IxCol, IxCol) -> m e
  encodeIx :: m e -> LexOrd -> (IxRow, IxCol) -> LexIx
  decodeIx :: m e -> LexOrd -> LexIx -> (IxRow, IxCol)


-- data RowsFirst = RowsFirst
-- data ColsFirst = ColsFirst

-- class SpContainer m e => SparseMatrix m o e where
--   smFromVector :: o -> (Int, Int) -> V.Vector (IxRow, IxCol, e) -> m e
--   -- smFromFoldableDense :: Foldable t => t e -> m e  
--   smTranspose :: o -> m e -> m e
--   -- smExtractSubmatrix ::
--   --   m e -> (IxRow, IxRow) -> (IxCol, IxCol) -> m e
--   encodeIx :: m e -> o -> (IxRow, IxCol) -> LexIx
--   decodeIx :: m e -> o -> LexIx -> (IxRow, IxCol)






-- * SparseMatVec

-- | Combining functions for relating (structurally) matrices and vectors, e.g. extracting/inserting rows/columns/submatrices

-- class (SparseMatrix m o e, SparseVector v e) => SparseMatVec m o v e where
--   smvInsertRow :: m e -> v e -> IxRow -> m e
--   smvInsertCol :: m e -> v e -> IxCol -> m e
--   smvExtractRow :: m e -> IxRow -> v e
--   smvExtractCol :: m e -> IxCol -> v e  







-- -- | Instances for AdditiveGroup
-- instance Integral a => AdditiveGroup (Ratio a) where
--   {zero=0; (^+^) = (+); negated = negate}

-- instance (RealFloat v, AdditiveGroup v) => AdditiveGroup (Complex v) where
--   zero    = zero :+ zero
--   (^+^)   = (+)
--   negated = negate

-- -- | Standard instance for an applicative functor applied to a vector space.
-- instance AdditiveGroup v => AdditiveGroup (a -> v) where
--   zero    = pure   zero
--   (^+^)   = liftA2 (^+^)
--   negated = fmap   negated


-- -- | Instances for VectorSpace
-- instance (RealFloat v, VectorSpace v) => VectorSpace (Complex v) where
--   type Scalar (Complex v) = Scalar v
--   s .* (u :+ v) = s .* u :+ s .* v



-- #define ScalarType(t) \
--   instance AdditiveGroup (t) where {zero = 0; (^+^) = (+); negated = negate};\
--   instance VectorSpace (t) where {type Scalar (t) = (t); (.*) = (*) };\
--   instance Hilbert (t) where dot = (*)

-- ScalarType(Int)
-- ScalarType(Integer)
-- ScalarType(Float)
-- ScalarType(Double)
-- ScalarType(CSChar)
-- ScalarType(CInt)
-- ScalarType(CShort)
-- ScalarType(CLong)
-- ScalarType(CLLong)
-- ScalarType(CIntMax)
-- ScalarType(CFloat)
-- ScalarType(CDouble)
