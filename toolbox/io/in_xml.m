function sXml = in_xml(XmlFile)
% IN_XML: Reads an XML file and return a Matlab structure with all the information

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2012-2018

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

% Create the parser
dbf = DocumentBuilderFactory.newInstance();
dbf.setValidating(false);
dbf.setFeature('http://xml.org/sax/features/namespaces', 0);
dbf.setFeature('http://xml.org/sax/features/validation', 0);
dbf.setFeature('http://apache.org/xml/features/nonvalidating/load-dtd-grammar', 0);
dbf.setFeature('http://apache.org/xml/features/nonvalidating/load-external-dtd', 0);
% Parse XML string
if (XmlFile(1) == '<')
    jFile = org.xml.sax.InputSource(java.io.StringReader(XmlFile));
% Parse XML file
else
    jFile = java.io.File(XmlFile);
end
DocXml = dbf.newDocumentBuilder().parse(jFile);
DocXml.getDocumentElement().normalize();
% Process root node
node = DocXml.getDocumentElement();
nodeName = file_standardize(char(node.getNodeName()));
sXml.(nodeName) = ParseTree(node);

% Conversion function: Java Node tree => Matlab structure
function sNode = ParseTree(node)
    sNode = struct();
    % Get node attributes
    attrList = node.getAttributes();
    for iAttr = 0:(attrList.getLength()-1)
        attrName = file_standardize(char(attrList.item(iAttr).getName()));
        attrVal  = char(attrList.item(iAttr).getValue());
        sNode.(attrName) = attrVal;
    end
    % Process children
    for iChild = 0:(node.getLength()-1)
        % Process depends on the node type
        switch (node.item(iChild).getNodeType())
            case node.ELEMENT_NODE
                % Read the node name and data
                childName = file_standardize(char(node.item(iChild).getNodeName()));
                % Read child information
                sChild = ParseTree(node.item(iChild));
                % Keep child only if there is info in it
                if ~isempty(fieldnames(sChild))
                    if ~isfield(sNode, childName)
                        sNode.(childName) = sChild;
                    else
                        % sNode.(childName)(iEnd+1) = struct_copy_fields(sNode.(childName)(iEnd), sChild, 1);
                        iNode = length(sNode.(childName)) + 1;
                        fields = fieldnames(sChild);
                        for iField = 1:length(fields)
                            sNode.(childName)(iNode).(fields{iField}) = sChild.(fields{iField});
                        end
                    end
                elseif ~isfield(sNode, childName)
                    sNode.(childName) = [];
                end
            case node.TEXT_NODE
                nodeText = strtrim(char(node.item(iChild).getNodeValue));
                if ~isempty(nodeText)
                    sNode.text = nodeText;
                end
            case node.COMMENT_NODE
                nodeText = strtrim(char(node.item(iChild).getNodeValue));
                if ~isempty(nodeText)
                    sNode.comment = nodeText;
                end
            case node.CDATA_SECTION_NODE
                nodeText = strtrim(char(node.item(iChild).getNodeValue));
                if ~isempty(nodeText)
                    sNode.cdata = nodeText;
                end
            otherwise
                disp(sprintf('Ignored node type: %d', node.item(iChild).getNodeType()));
        end
    end
end

end

