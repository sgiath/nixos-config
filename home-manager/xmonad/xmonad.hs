import Colors
import System.Exit (exitSuccess)
import XMonad
import XMonad.Actions.CycleWS (nextScreen, nextWS, prevWS)
import XMonad.Actions.MouseResize (mouseResize)
import XMonad.Actions.OnScreen
import XMonad.Config.Desktop (desktopConfig)
import XMonad.Hooks.DynamicLog (PP (..), dynamicLogWithPP, shorten, wrap, xmobarColor, xmobarPP)
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Hooks.ManageDocks (ToggleStruts (..), avoidStruts, docksEventHook, manageDocks)
import XMonad.Hooks.ManageHelpers (doFullFloat, isFullscreen)
import XMonad.Layout.GridVariants (Grid (Grid))
import XMonad.Layout.LayoutModifier (ModifiedLayout)
import XMonad.Layout.LimitWindows (limitWindows)
import XMonad.Layout.Magnifier (magnifier)
import XMonad.Layout.MultiToggle (EOT (EOT), mkToggle, single, (??))
import qualified XMonad.Layout.MultiToggle as MT (Toggle (..))
import XMonad.Layout.MultiToggle.Instances (StdTransformers (MIRROR, NBFULL, NOBORDERS))
import XMonad.Layout.NoBorders (noBorders, smartBorders)
import XMonad.Layout.PerWorkspace (onWorkspace)
import XMonad.Layout.Reflect
import XMonad.Layout.Renamed (Rename (Replace), renamed)
import XMonad.Layout.ResizableTile
import XMonad.Layout.Simplest
import XMonad.Layout.Spacing
import XMonad.Layout.SubLayouts (subLayout)
import XMonad.Layout.Tabbed
import qualified XMonad.Layout.ToggleLayouts as T (ToggleLayout (Toggle), toggleLayouts)
import XMonad.Layout.ThreeColumns (ThreeCol( ThreeColMid ))
import XMonad.Layout.WindowArranger (WindowArrangerMsg (..), windowArrange)
import XMonad.Layout.WindowNavigation
import XMonad.Util.EZConfig (additionalKeysP)
import XMonad.Util.Run
import XMonad.Util.SpawnOnce
import qualified XMonad.StackSet as W

baseConfig =
  desktopConfig
    { modMask = mod4Mask,
      terminal = "wezterm",
      workspaces = myWorkspaces,
      borderWidth = 0
    }

myWorkspaces = ["term", "web", "work", "firefox", "5", "6", "7", "audio", "email", "chat"]
myFont = "xft:RobotoMono Nerd Font Mono:regular:size=9:antialias=true:hinting=true"
myLayoutHook =
    avoidStruts $
      onWorkspace "Firefox" full $
        onWorkspace "audio" tabs $
          onWorkspace "chat" tabs $
            smartBorders $
              mouseResize $
                windowArrange $
                  (reflectHoriz tall ||| tabs ||| record)
  where
    myTabTheme =
      def
        { fontName = myFont,
          activeColor = colorOrangeBright,
          inactiveColor = colorBlue,
          activeBorderColor = colorOrangeBright,
          inactiveBorderColor = colorBg,
          activeTextColor = colorBg,
          inactiveTextColor = colorFg
        }
    threeColMid =
      windowNavigation $
        subLayout [] (smartBorders Simplest) $
          limitWindows 5 $
            ThreeColMid 1 (3/100) (1/2)
    tall = renamed [Replace "tall"] $ windowNavigation $ subLayout [] (smartBorders Simplest) $ Tall 1 (3/100) (4/5)
    full = noBorders Full
    tabs = noBorders $ renamed [Replace "tabs"] $ tabbed shrinkText myTabTheme
    record = noBorders $ threeColMid

myManageHook =
  composeAll
    [ className =? "confirm" --> doFloat,
      className =? "file_progress" --> doFloat,
      className =? "dialog" --> doFloat,
      className =? "download" --> doFloat,
      className =? "error" --> doFloat,
      className =? "notification" --> doFloat,
      className =? "splash" --> doFloat,
      className =? "toolbar" --> doFloat,
      isFullscreen --> doFullFloat,
      -- Default WS
      className =? "wezterm" --> doShift "term",
      className =? "kitty" --> doShift "term",
      className =? "Chromium-browser" --> doShift "web",
      className =? "Google-chrome" --> doShift "work",
      className =? "firefox" --> doShift "Firefox",
      className =? "easyeffects" --> doShift "audio",
      className =? "qpwgraph" --> doShift "audio",
      className =? "Claws-mail" --> doShift "email",
      className =? "Slack" --> doShift "chat",
      className =? "TelegramDesktop" --> doShift "chat",
      className =? "WebCord" --> doShift "chat"
    ]

myKeys =
  [
    -- terminal
    ("M-<Return>", spawn "wezterm"),
    -- Rofi
    ("M-/", spawn "rofi -show drun"),
    -- Layout
    ("M-S-<Space>", sendMessage ToggleStruts),
    ("M-<Right>", nextWS),
    ("M-<Left>", prevWS),
    -- Halmak rebinding
    ("M-1", windows $ W.greedyView (myWorkspaces !! 0)),
    ("M-2", windows $ W.greedyView (myWorkspaces !! 1)),
    ("M-3", windows $ W.greedyView (myWorkspaces !! 2)),
    ("M-4", windows $ W.greedyView (myWorkspaces !! 3)),
    ("M-5", windows $ W.greedyView (myWorkspaces !! 4)),
    ("M-6", windows $ W.greedyView (myWorkspaces !! 5)),
    ("M-7", windows $ W.greedyView (myWorkspaces !! 6)),
    ("M-8", windows $ W.greedyView (myWorkspaces !! 7)),
    ("M-9", windows $ W.greedyView (myWorkspaces !! 8)),
    ("M-0", windows $ W.greedyView (myWorkspaces !! 9)),
    ("M-S-1", windows $ W.shift (myWorkspaces !! 0)),
    ("M-S-2", windows $ W.shift (myWorkspaces !! 1)),
    ("M-S-3", windows $ W.shift (myWorkspaces !! 2)),
    ("M-S-4", windows $ W.shift (myWorkspaces !! 3)),
    ("M-S-5", windows $ W.shift (myWorkspaces !! 4)),
    ("M-S-6", windows $ W.shift (myWorkspaces !! 5)),
    ("M-S-7", windows $ W.shift (myWorkspaces !! 6)),
    ("M-S-8", windows $ W.shift (myWorkspaces !! 7)),
    ("M-S-9", windows $ W.shift (myWorkspaces !! 8)),
    ("M-S-0", windows $ W.shift (myWorkspaces !! 9))
  ]

main :: IO ()
main = do
  xmonad $
    ewmh $
      baseConfig
        { manageHook = manageHook baseConfig <+> myManageHook,
          layoutHook = myLayoutHook
        }
        `additionalKeysP` myKeys
