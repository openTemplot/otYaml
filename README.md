otYaml is a port of the 'C' libYaml library and the Delphi Neslib.Yaml library to FreePascal/Lazarus

There is very little of the original sources left, but there are bits and pieces that might be recognisable.

The libYaml port follows the original C code fairly directly, although it uses Exceptions rather than return codes for reporting error states.

The Neslib.Yaml port (which provides a DOM-style interface on top of the libYaml event-based interface) is actually quite different to the original as it uses more standard Pascal structures and has been geared to readability rather than outright performance.

To use these libraries include the contents of the `src` directory into your project. Use the TYamlEmitter and TYamlParser classes if you want to use the event-based interface (equivalent to libYaml). Use the TYamlDocument/TYamlStream classes (in otYamlDOM) to use the DOM-based interface.

There are tests for the libraries in the `Test` directory, along with test data. There are 3 projects that build applications to test the Parser, Emitter and DOM interfaces. There are Python scripts that run the test suites against each of the test data directories.

