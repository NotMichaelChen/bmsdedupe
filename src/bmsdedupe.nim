import algorithm
import options
import os
import std/paths
import sequtils
import sets
import strformat
import strutils
import sugar
import tables

import db_connector/db_sqlite

when isMainModule:
  let args = commandLineParams()

  doAssert(args.len == 1, fmt"Expected exactly one arguments, got {args.len} instead")
  let dbFilePath = args[0]

  doAssert(isAbsolute(dbFilePath), "Database file path needs to be an absolute path, not a relative path")

  let db = open(dbFilePath, "", "", "")

  let dupedHashesQuery = """
    WITH hashes AS (
      SELECT sha256, COUNT(sha256) c
      FROM song
      GROUP BY sha256
      HAVING c > 1
    )
    SELECT sha256, path
    FROM song
    JOIN hashes
    USING (sha256)
  """.dedent()

  var pathsByHash: Table[string, HashSet[string]]
  for row in db.rows(sql(dupedHashesQuery)):
    let hash = row[0]
    let filePath = row[1]

    let (rawPath, _, _) = splitFile(Path(filePath))
    let path =
      if not rawPath.isAbsolute():
        let (basePath, _, _) = splitFile(Path(dbFilePath))
        joinPath(basePath.string, rawPath.string)
      else:
        rawPath.string
    pathsByHash.mgetOrPut(hash, initHashSet[string]()).incl(path)

  var pathsSets: HashSet[HashSet[string]]
  for pathsSet in pathsByHash.values:
    if pathsSet.len > 1:
      pathsSets.incl(pathsSet)

  var duplicatedPaths = pathsSets.toSeq

  var finalPaths: seq[HashSet[string]]

  # for each path group:
  #   compute intersection with other remaining path groups
  #   if intersection, union with original path group and remove from list
  #   place final path group in separate list
  while duplicatedPaths.len > 0:
    var basePaths = duplicatedPaths[0]
    var index = 1
    while index < duplicatedPaths.len:
      if not disjoint(basePaths, duplicatedPaths[index]):
        basePaths = basePaths.union(duplicatedPaths[index])
        duplicatedPaths.del(index)
      else:
        index += 1
    finalPaths.add(basePaths)
    duplicatedPaths.del(0)

  for pathIndex, paths in finalPaths:
    var pathsArray = paths.toSeq().sorted()

    var continueLoop = true
    var chosenIndex = -1
    while continueLoop:
      echo fmt"Group ({pathIndex+1}/{finalPaths.len})"
      for index, path in pathsArray:
        echo fmt"({index}) {path}"
      echo fmt"({pathsArray.len}) Skip"

      stdout.write("Select option: ")
      let rawSelection = stdin.readLine()
      let selection =
        try:
          some(rawSelection.parseInt()).flatMap((n: int) => (
            if n > pathsArray.len or n < 0:
              none(int)
            else:
              some(n)
          ))
        except ValueError:
          none(int)
      
      if selection.isSome:
        chosenIndex = selection.get
        continueLoop = false
    
    if chosenIndex == pathsArray.len:
      continue
    
    let mergedInto = pathsArray[chosenIndex]
    pathsArray.del(chosenIndex)

    for path in pathsArray:
      copyDir(path, mergedInto)
      removeDir(path)
  
  db.close()
