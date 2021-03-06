module VabalMain where

import ArgumentParsers
import GhcMetadata

import Distribution.Types.GenericPackageDescription
import Options.Applicative

import System.Directory
import System.FilePath

import VabalError

import VabalContext
import GhcDatabase

import GhcupProgram

import CabalAnalyzer
import UserInterface

import XArgsEscape

import Distribution.Types.Version

import Control.Monad (unless)

import qualified Data.ByteString as B

import qualified Data.Set as S

data VabalMainArguments = VabalMainArguments
               { versionSpecification :: VersionSpecification
               , configFlags          :: FlagAssignment
               , cabalFile            :: Maybe FilePath
               , noInstallFlag        :: Bool
               , alwaysNewestFlag     :: Bool
               }
               deriving(Show)

mainArgumentsParser :: Parser VabalMainArguments
mainArgumentsParser = VabalMainArguments
                   <$> versionSpecificationOptions
                   <*> flagsOption
                   <*> cabalFileOption
                   <*> noInstallSwitch
                   <*> alwaysNewestSwitch

findCabalFile :: IO FilePath
findCabalFile = do
    currDir <- getCurrentDirectory
    childs <- listDirectory currDir
    let cabalFiles = filter (\c -> takeExtension c == ".cabal") childs
    case cabalFiles of
        [] -> throwVabalErrorIO "No cabal file found."
        (cf:_) -> return cf

mainProgDesc :: String
mainProgDesc = "Finds a version of GHC that is compatible with \
               \ the constraints imposed on base package found \
               \ in the cabal file analyzed, \
               \ then uses ghcup to obtain it (possibly downloading it). \
               \ Finally it prints to stdout options you can feed \
               \ to cabal to use the obtained GHC compiler \
               \ (options are already escaped so that they can sent to xargs). \
               \ WARNING: Probably this is not what you want to use, \
               \ See \"vabal configure --help\" for info about how to \
               \ directly configure your project to use the found GHC compiler."

makeVabalContext :: VabalMainArguments -> IO VabalContext
makeVabalContext args = do
    ghcMetadataDir <- getGhcMetadataDir
    let ghcMetadataPath = ghcMetadataDir </> ghcMetadataFilename
    ghcDb <- readGhcDatabase ghcMetadataPath
    installedGhcs <- filterGhcVersions ghcDb . S.fromList <$> getInstalledGhcs

    return $ VabalContext installedGhcs ghcDb (alwaysNewestFlag args)

vabalFindGhcVersion :: VabalMainArguments -> VabalContext -> IO Version
vabalFindGhcVersion args vabalCtx = do
    cabalFilePath <- maybe findCabalFile return (cabalFile args)
    cabalFileContents <- B.readFile cabalFilePath

    let flags = configFlags args

    case versionSpecification args of
        GhcVersion ghcVer -> do
            let res = checkIfGivenVersionWorksForAllTargets flags
                                                            vabalCtx
                                                            cabalFileContents
                                                            ghcVer
            unless res $
                writeWarning "Warning: The specified ghc version probably won't work."
            return ghcVer

        BaseVersion baseVer -> return $
                      analyzeCabalFileAllTargets flags
                                                 vabalCtx
                                                 (Just baseVer)
                                                 cabalFileContents

        NoSpecification -> return $
                      analyzeCabalFileAllTargets flags
                                                 vabalCtx
                                                 Nothing
                                                 cabalFileContents


vabalMain :: VabalMainArguments -> IO ()
vabalMain args = do
    vabalCtx <- makeVabalContext args
    version <- vabalFindGhcVersion args vabalCtx
    ghcLocation <- requireGHC (availableGhcs vabalCtx) version (noInstallFlag args)
    writeMessage $ "Selected GHC version: " ++ prettyPrintVersion version

    -- Output generation
    writeOutput $ generateCabalOptions args ghcLocation


generateCabalOptions :: VabalMainArguments -> FilePath -> String
generateCabalOptions args ghcLocation =
    let flagsOutput = unwords
              . map showFlagValue $ unFlagAssignment (configFlags args)

        outputGhcLocationArg = "-w\n" ++ escapeForXArgs ghcLocation
        outputFlagsArg = if null flagsOutput then
                            ""
                         else
                           -- we don't escape flags because we are sure no invalid
                           -- sequence is in them, since otherwise they weren't
                           -- parsed when passed as arguments
                           "\n--flags\n'" ++ flagsOutput ++ "'"

        outputCabalFile = case cabalFile args of
                             Nothing -> ""
                             Just cabalFilePath -> "\n--cabal-file\n" ++ escapeForXArgs cabalFilePath

    in outputGhcLocationArg ++ outputFlagsArg ++ outputCabalFile

