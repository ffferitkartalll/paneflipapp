/// The apps installed on this Mac, for the launcher of a zone.
protocol InstalledAppListing {
    /// Every app of the usual folders that shows up in the Dock, in alphabetical order. Reads the disk: not for the main thread.
    func apps() -> [InstalledApp]
}
