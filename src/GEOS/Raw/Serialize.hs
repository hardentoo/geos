module GEOS.Raw.Serialize (
    createReader
  , createWriter
  , read
  , readHex
  , write
  , writeHex
) where
import Prelude hiding (read)
import qualified GEOS.Raw.Internal as I
import GEOS.Raw.Base
import GEOS.Raw.Geometry
import Foreign
import Foreign.C.String
import Foreign.C.Types
import Foreign.Marshal.Alloc
import Foreign.Ptr
import Foreign.ForeignPtr
import qualified Data.ByteString.Char8 as BC
import System.IO.Unsafe


newtype Reader = Reader { _unReader :: ForeignPtr I.GEOSWKBReader }
newtype Writer = Writer { _unWriter :: ForeignPtr I.GEOSWKBWriter }

withReader (Reader r) f = withForeignPtr r f
withWriter (Writer w) f = withForeignPtr w f

createReader :: Geos Reader
createReader = withGeos $ \h -> do 
    ptr <- throwIfNull "Create Reader" $ 
      I.geos_WKBReaderCreate h  
    fp <- newForeignPtrEnv I.geos_WKBReaderDestroy h ptr
    return $ Reader fp

read_ :: (I.GEOSContextHandle_t -> Ptr I.GEOSWKBReader -> CString  -> CSize -> IO (Ptr I.GEOSGeometry)) 
            -> Reader 
            -> BC.ByteString 
            -> Geos Geometry
read_ f r bs = withGeos $ \h -> do
  ptr <- withReader r $ \rp -> 
            BC.useAsCStringLen bs $ \(cs, l) -> 
              f h rp cs $ fromIntegral l 
  fp <- newForeignPtrEnv I.geos_GeomDestroy h ptr
  return $ Geometry fp
  

read :: Reader -> BC.ByteString -> Geos Geometry
read = read_ I.geos_WKBReaderRead
  
readHex :: Reader -> BC.ByteString -> Geos Geometry
readHex = read_ I.geos_WKBReaderReadHex

createWriter :: Geos Writer
createWriter = withGeos $ \h -> do
  ptr <- throwIfNull "CreateWriter" $ I.geos_WKBWriterCreate h 
  fp <- newForeignPtrEnv I.geos_WKBWriterDestroy h ptr
  return $ Writer fp
        
write_ :: (I.GEOSContextHandle_t -> Ptr I.GEOSWKBWriter -> Ptr I.GEOSGeometry -> Ptr CSize -> IO CString)
          -> Writer
          -> Geometry
          -> Geos BC.ByteString
write_ f w g = withGeos $ \h ->  do
  s <- withWriter w $ \wp ->
          withGeometry g $ \gp -> 
            alloca $ \lp ->
              f h wp gp lp 
  bs <- BC.packCString s          
  return bs
                     
write :: Writer -> Geometry -> Geos BC.ByteString
write = write_ I.geos_WKBWriterWrite

writeHex :: Writer -> Geometry -> Geos BC.ByteString
writeHex = write_ I.geos_WKBWriterWriteHex