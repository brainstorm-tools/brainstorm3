function [VertexLabelIds, LabelMap, AtlasName] = in_label_bs(FileName)
% IN_LABEL_SVREG: Import an atlas from an SVReg-labelled surface
%
% USAGE: in_label_bs(FileName, Verbosity=1) : Load labeled vertices from given file
%
% INPUT
%       - FileName : full path of SVReg surface file to read
%
% OUTPUT
%       - LabelIds :  vector of vertex label ids
%       - LabelMap : java.util.HashMap of label names and colors for corresponding vertex index.
%           - LabelMap.get(id): cell containing label name and color of id i

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
% Authors: Andrew Krause, 2013


% ===== Read XML Label Description File =====
fPath = bst_fileparts(FileName);

st=strfind(FileName,'.svreg.');
ed=strfind(FileName,'.dfs');
AtlasName = FileName(st+7:ed-1);

XmlFile = file_find(fPath, ['brainsuite_labeldescription*',AtlasName,'.xml']);
if isempty(XmlFile)
    fprintf(1, 'BST> For Atlas %s could not find XML label description file brainsuite_labeldescription.xml\n', AtlasName);
    fprintf(1, 'BST> Only label Ids will be used for this atlas without label names\n');
    LabelMap = [];
else
    LabelMap = generate_label_map(XmlFile);
end


% ===== Get Vertex Labels from DFS FILE =====
VertexLabelIds = get_vertex_label_ids(FileName);


end



%% ======================================================================================
%  ===== HELPER FUNCTIONS ===============================================================
%  ======================================================================================
%% Generate mapping between label id and label name and color
function labelMap = generate_label_map(xmlFileName)
    import javax.xml.xpath.*
    
    try
        docNode = xmlread(xmlFileName);
    catch
        error('Could not open XML Label Description: %s', xmlFileName);
    end

    factory = XPathFactory.newInstance;
    xPath = factory.newXPath;
    
    idsExpression    = xPath.compile('//label/@id');
    tagsExpression   = xPath.compile('//label/@fullname');
    colorsExpression = xPath.compile('//label/@color');
    idsList    = idsExpression.evaluate(docNode, XPathConstants.NODESET);
    tagsList   = tagsExpression.evaluate(docNode, XPathConstants.NODESET);
    colorsList = colorsExpression.evaluate(docNode, XPathConstants.NODESET);
    

    numLabels = idsList.getLength;
    labelMap = java.util.HashMap;
    for i = 1:numLabels
        idNode = idsList.item(i-1);
        tagNode = tagsList.item(i-1);
        colorNode = colorsList.item(i-1);

        % Convert color from hexadecimal to RGB [0, 1]
        colorHex = char(colorNode.getNodeValue);
        while length(colorHex) < 8, colorHex = [colorHex '0']; end
        color = [hex2dec(colorHex(3:4)) hex2dec(colorHex(5:6)) hex2dec(colorHex(7:8))] ./ 255;
        
        % Add ids, names, and colors to hashmap
        id = char(idNode.getNodeValue);
        labelName = char(tagNode.getNodeValue);
        if strncmp(labelName, 'L.', 2) || strncmp(labelName, 'R.', 2)
            labelName = labelName(4:end);
        end
        labelMap.put(id, {labelName, color});
    end
end


%% Return the label ids of each vertex
function Labels = get_vertex_label_ids(s)
    fid=fopen(s,'r');
    if (fid<0) 
        error('Unable to read surface: %s',s);
    end

    %% ===== Read number of vertices in surface and labels =====
    fseek(fid, 28, -1); % Skip to nVertices
    nVertices = fread(fid,1,'int32');
    fseek(fid, 20, 0); % Skip to labelOffset
    LabelOffset = fread(fid,1,'int32');

    if (LabelOffset > 0)
        fseek(fid, LabelOffset, -1);
        Labels = fread(fid, nVertices,'uint16');
    else
        error('Surface does not have label attributes');
    end
    fclose(fid);
end
