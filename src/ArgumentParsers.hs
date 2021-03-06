module ArgumentParsers where

import Options.Applicative
import Distribution.Version
import Distribution.Types.GenericPackageDescription
import Distribution.Parsec.Class
import Distribution.Parsec.FieldLineStream (fieldLineStreamFromString)

data VersionSpecification = GhcVersion Version
                          | BaseVersion Version
                          | NoSpecification
                          deriving(Show)

versionParser :: ReadM Version
versionParser = maybeReader simpleParsec

ghcVersionOption :: Parser VersionSpecification
ghcVersionOption = GhcVersion
                  <$> option versionParser
                      ( long "with-ghc-version"
                      <> short 'g'
                      <> metavar "VER"
                      <> help "Explicitly tell which version of ghc you want to use \
                              \ for the project. \
                              \ (Incompatible with option --with-base-version)"
                      )

baseVersionOption :: Parser VersionSpecification
baseVersionOption = BaseVersion
                   <$> option versionParser
                       ( long "with-base-version"
                       <> short 'b'
                       <> metavar "VER"
                       <> help "Specify the version of base package you want to use. \
                                \ It is going to be checked against base constraints in \
                                \ the cabal file for validity. \
                                \ (Incompatible with option --with-ghc-version)"
                       )

versionSpecificationOptions :: Parser VersionSpecification
versionSpecificationOptions =
    ghcVersionOption <|> baseVersionOption <|> pure NoSpecification

flagAssignmentParser :: ReadM FlagAssignment
flagAssignmentParser = maybeReader $ \flagsString ->
    either (const Nothing) Just $
        runParsecParser parsecFlagAssignment "<flagParsec>"
                        (fieldLineStreamFromString flagsString)


flagsOption :: Parser FlagAssignment
flagsOption = option flagAssignmentParser
               ( long "flags"
               <> metavar "FLAGS"
               <> help "String containing a list  of space separated flags \
                       \ to be used to configure the project \
                       \ (You can enable or disable a flag by adding a + or - \
                       \ in front of the flag name. \
                       \ When none is specified, the flag is enabled). \
                       \ Flag assignment determined here is forwarded \
                       \ to cabal."
               <> value (mkFlagAssignment [])
               )

cabalFileOption :: Parser (Maybe FilePath)
cabalFileOption = optional
                  ( strOption
                      ( long "cabal-file"
                      <> metavar "FILE"
                      <> help "Explicitly tell which cabal file to use. \
                               \ This option is forwarded to cabal."
                      )
                  )

noInstallSwitch :: Parser Bool
noInstallSwitch = switch
                  ( long "no-install"
                  <> help "If GHC needs to be downloaded, fail, instead."
                  )


alwaysNewestSwitch :: Parser Bool
alwaysNewestSwitch = switch
                     ( long "always-newest"
                     <> help "Always choose newest GHC possible, don't prefer \
                             \ already installed GHCs"
                     )
