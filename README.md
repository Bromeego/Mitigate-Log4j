# Mitigate-Log4j
Yet another Log4j Mitigation Script

# What does it do
Scans your system for the presence of any log4j-core*.jar files
Checks your system for 7-Zip, if not installed it will try and download then install your to your system for the scan.
7-zip is needed as previous server/client versions of Windows do not have a default Zip command.

The script then removes the JndiLookup.class file from the .jar
Rescans the .jar file to report if the file was removed.

Happy to have issues reported and Pull Requests added.
