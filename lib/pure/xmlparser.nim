#
#
#            Nimrod's Runtime Library
#        (c) Copyright 2010 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module parses an XML document and creates its XML tree representation.

import streams, parsexml, strtabs, xmltree

type
  EInvalidXml* = object of EInvalidValue ## exception that is raised
                                         ## for invalid XML
    errors*: seq[string]                 ## all detected parsing errors

proc raiseInvalidXml(errors: seq[string]) = 
  var e: ref EInvalidXml
  new(e)
  e.msg = errors[0]
  e.errors = errors
  raise e

proc addNode(father, son: PXmlNode) = 
  if son != nil: add(father, son)

proc parse(x: var TXmlParser, errors: var seq[string]): PXmlNode

proc untilElementEnd(x: var TXmlParser, result: PXmlNode, 
                     errors: var seq[string]) =
  while true:
    case x.kind
    of xmlElementEnd: 
      if x.elementName == result.tag: 
        next(x)
      else:
        errors.add(errorMsg(x, "</" & result.tag & "> expected"))
        # do not skip it here!
      break
    of xmlEof:
      errors.add(errorMsg(x, "</" & result.tag & "> expected"))
      break
    else:
      result.addNode(parse(x, errors))

proc parse(x: var TXmlParser, errors: var seq[string]): PXmlNode =
  case x.kind
  of xmlComment: 
    result = newComment(x.charData)
    next(x)
  of xmlCharData, xmlWhitespace:
    result = newText(x.charData)
    next(x)
  of xmlPI, xmlSpecial:
    # we just ignore processing instructions for now
    next(x)
  of xmlError:
    errors.add(errorMsg(x))
    next(x)
  of xmlElementStart:    ## ``<elem>``
    result = newElement(x.elementName)
    next(x)
    untilElementEnd(x, result, errors)
  of xmlElementEnd:
    errors.add(errorMsg(x, "unexpected ending tag: " & x.elementName))
  of xmlElementOpen: 
    result = newElement(x.elementName)
    next(x)
    result.attrs = newStringTable()
    while true: 
      case x.kind
      of xmlAttribute:
        result.attrs[x.attrKey] = x.attrValue
        next(x)
      of xmlElementClose:
        next(x)
        break
      of xmlError:
        errors.add(errorMsg(x))
        next(x)
        break
      else:
        errors.add(errorMsg(x, "'>' expected"))
        next(x)
        break
    untilElementEnd(x, result, errors)
  of xmlAttribute, xmlElementClose:
    errors.add(errorMsg(x, "<some_tag> expected"))
    next(x)
  of xmlCData: 
    result = newCData(x.charData)
    next(x)
  of xmlEntity:
    ## &entity;
    errors.add(errorMsg(x, "unknown entity: " & x.entityName))
    next(x)
  of xmlEof: discard

proc parseXml*(s: PStream, filename: string, 
               errors: var seq[string]): PXmlNode = 
  ## parses the XML from stream `s` and returns a ``PXmlNode``. Every
  ## occured parsing error is added to the `errors` sequence.
  var x: TXmlParser
  open(x, s, filename, {reportComments})
  while true:
    x.next()
    case x.kind
    of xmlElementOpen, xmlElementStart: 
      result = parse(x, errors)
      break
    of xmlComment, xmlWhitespace, xmlSpecial, xmlPI: discard # just skip it
    of xmlError:
      errors.add(errorMsg(x))
    else:
      errors.add(errorMsg(x, "<some_tag> expected"))
      break
  close(x)

proc parseXml*(s: PStream): PXmlNode = 
  ## parses the XTML from stream `s` and returns a ``PXmlNode``. All parsing
  ## errors are turned into an ``EInvalidXML`` exception.
  var errors: seq[string] = @[]
  result = parseXml(s, "unknown_html_doc", errors)
  if errors.len > 0: raiseInvalidXMl(errors)

proc loadXml*(path: string, errors: var seq[string]): PXmlNode = 
  ## Loads and parses XML from file specified by ``path``, and returns 
  ## a ``PXmlNode``. Every occured parsing error is added to the `errors`
  ## sequence.
  var s = newFileStream(path, fmRead)
  if s == nil: raise newException(EIO, "Unable to read file: " & path)
  result = parseXml(s, path, errors)

proc loadXml*(path: string): PXmlNode = 
  ## Loads and parses XML from file specified by ``path``, and returns 
  ## a ``PXmlNode``.  All parsing errors are turned into an ``EInvalidXML``
  ## exception.  
  var errors: seq[string] = @[]
  result = loadXml(path, errors)
  if errors.len > 0: raiseInvalidXMl(errors)

when isMainModule:
  import os

  var errors: seq[string] = @[]  
  var x = loadXml(paramStr(1), errors)
  for e in items(errors): echo e
  
  var f: TFile
  if open(f, "xmltest.txt", fmWrite):
    f.write($x)
    f.close()
  else:
    quit("cannot write test.txt")
    
