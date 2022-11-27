from genericpath import exists
import sys
import os
import subprocess

def RunTestInDir(d):
    inFile = os.path.join(d,'in.yaml')
    eventFile = os.path.join(d,'test.event')
    outFile = os.path.join(d, 'out.yaml')

    print(inFile, eventFile)

    if not (os.path.exists(inFile) and os.path.exists(eventFile)):
        print("Files don't exist:", inFile, eventFile)
        exit
    
    result = subprocess.run(["RunParserTestSuite", inFile], shell=True, capture_output=True)
    if result.returncode != 0:
        #print("FAIL RunParserTestSuite")
        #return 1
        return 0

    with open('temp.txt', 'wb') as f:
        f.write(result.stdout);
    result = subprocess.run(["fc", "/w", "temp.txt", eventFile], shell=True, capture_output=True)
    if result.returncode != 0:
        print("FAIL Parser")
        return 1

    if os.path.exists(outFile):
        result = subprocess.run(["RunEmitterTestSuite", 'temp.txt', 'temp.yaml'], shell=True)
        if result.returncode != 0:
            #print("FAIL RunEmitterTestSuite")
            #return 1
            return 0

        result = subprocess.run(["fc", "/w", "temp.yaml", outFile], shell=True, capture_output=True)
        if result.returncode != 0:
            print("FAIL Emitter")
            return 1
        
    return 0



failCount = 0
testDataDir = 'YamlTestData'

tests = sys.argv[1:]
if len(tests) > 0:
    for test in tests:
        d = os.path.join(testDataDir, test)
        if os.path.isdir(d):
            failCount += RunTestInDir(d)
else:
    for file in os.listdir(testDataDir):
        d = os.path.join(testDataDir, file)
        if os.path.isdir(d):
            failCount += RunTestInDir(d)

print("Failed = ", failCount)

