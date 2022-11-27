from genericpath import exists
import sys
import os
import subprocess
import re
import yaml
import dictdiffer

def YamlEquivalent(a,b):
    with open(a,'r') as rdr:
        data1=rdr.read()

    with open(b,'r') as rdr:
        data2=rdr.read()

    data1_dict = yaml.load(data1,Loader=yaml.FullLoader)
    data2_dict = yaml.load(data2,Loader=yaml.FullLoader)

    return data1_dict == data2_dict

def RunTestInDir(d):
    inFile = os.path.join(d,'in.yaml')
    outFile = os.path.join(d, 'out.yaml')

    if not os.path.exists(inFile):
        #print("Input files don't exist:", inFile)
        return 0
        
    print("Files: ", inFile, outFile)
    if os.path.exists("temp.yaml"):
        os.remove("temp.yaml");
        
    
    result = subprocess.run(["RunDOMTestSuite", inFile, "temp.yaml"], shell=True, capture_output=True, encoding='utf-8')
    if result.returncode != 0:
        print("FAIL RunDOMTestSuite")
        return 1
        
    for line in result.stderr.split("\n"):
        m = re.search("^([0..9]+) unfreed memory blocks", line)
        if m:
            if m.group(1) != "0":
                print(line)
                print("FAIL MemoryLeak")
                return 1
      
    if not os.path.exists("temp.yaml"):
        print("FAIL temp.yaml not output")
        return 1
        
    if not os.path.exists(outFile):
        return 0


#    result = subprocess.run(["fc", "/w", "temp.yaml", outFile], shell=True, capture_output=True)
#    if result.returncode != 0:
#        print("FAIL DOM")
#        return 1

    if not YamlEquivalent("temp.yaml", outFile):
        print("FAIL DOM")
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

