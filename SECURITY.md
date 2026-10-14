# Security policy

## Reporting a vulnerability

Please do not report a security problem in a public issue. Use GitHub's private reporting instead: open the
**Security** tab of this repository and choose **Report a vulnerability**. Only the maintainer can read the
report.

Say what you found, how to reproduce it and which version or commit you used. You will get an answer as soon as
the maintainer can give one.

## What is in scope

PaneFlip runs on your Mac with the Accessibility permission, so a problem that lets another process misuse that
permission, run code through the app, or read or change data the app keeps (layouts, memory, settings) is in
scope. The app sends nothing off the Mac except the names of the apps in your zones to the icon host when brand
icons are on (see the README).

## Supported versions

Only the latest commit on `main` is supported.
