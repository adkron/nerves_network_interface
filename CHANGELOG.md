# Changelog

## v0.4.2

  * Bug fixes
    * Don't rely on hex preserving execute permissions on the shell script.

## v0.4.1

  * Enhancements
    * Support compilation on OSX. It won't run, but it's good enough for
      creating docs and pushing to hex.
    * Make MAC address handling more user friendly by using strings and
      supporting sets.

## v0.4.0

  * Enhancements
    * Replaced GenEvent with Registry

## v0.3.2

  * Bugs fixed
    * Clean up warnings for Elixir 1.4

## v0.3.2

  * Bugs fixed
    * Fix compilation error on Ubuntu 16.04

## v0.3.1

  * Bugs fixed
    * Fixes from integration with nerves_interim_wifi

## v0.3.0

Renamed from `net_basic.ex` to `nerves_network_interface`

  * New features
    * Sends events when interfaces appear and disappear (insertion/removal of a
      USB WiFi dongle)
    * Now an OTP application. You no longer need to add it to a supervision tree
      for use.
