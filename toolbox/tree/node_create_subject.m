function node_create_subject(nodeSubject, sSubject, iSubject)
% NODE_CREATE_SUBJECT: Create subject node from subject structure.
%
% USAGE:  node_create_subject(nodeSubject, sSubject, iSubject)
%
% INPUT: 
%     - nodeSubject : BstNode object with Type 'subject' => Root of the subject subtree
%     - sSubject    : Brainstorm subject structure
%     - iSubject    : indice of the subject node in Brainstorm subjects list

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, 2008-2016

% If iSubject=0 => default subject
import org.brainstorm.tree.*;

% Update node fields
nodeSubject.setFileName(sSubject.FileName);
nodeSubject.setItemIndex(0);
nodeSubject.setStudyIndex(iSubject);
if (iSubject ~= 0)
    nodeSubject.setComment(sSubject.Name);
else
    nodeSubject.setComment('(Default anatomy)');
end

% Anatomy files to use : Individual or Protocol defaults
% ==== Default anatomy ====
if sSubject.UseDefaultAnat && (iSubject ~= 0)
    nodeLink = BstNode('defaultanat', '(Default anatomy)', '', 0, 0);
    nodeSubject.add(nodeLink);

% ==== Individual anatomy ====
else
    % Create list of anat files (put the default at the top)
    iAnatList = 1:length(sSubject.Anatomy);
    iAnatList = [sSubject.iAnatomy, setdiff(iAnatList,sSubject.iAnatomy)];
    % Create and add anatomy nodes
    for iAnatomy = iAnatList
        nodeAnatomy = BstNode('anatomy', ...
                              char(sSubject.Anatomy(iAnatomy).Comment), ...
                              char(sSubject.Anatomy(iAnatomy).FileName), ...
                              iAnatomy, iSubject);
        % If current item is default one
        if ismember(iAnatomy, sSubject.iAnatomy)
            nodeAnatomy.setMarked(1);
        end
        nodeSubject.add(nodeAnatomy);
    end

    % Sort surfaces by category
    SortedSurfaces = db_surface_sort(sSubject.Surface);
    iSorted = [SortedSurfaces.IndexScalp, SortedSurfaces.IndexOuterSkull, SortedSurfaces.IndexInnerSkull, ...
               SortedSurfaces.IndexCortex, SortedSurfaces.IndexOther, SortedSurfaces.IndexFibers];
    % Process all the surfaces
    for i = 1:length(iSorted)
        iSurface = iSorted(i);
        SurfaceType = sSubject.Surface(iSurface).SurfaceType;
        % Create a node adapted to represent this surface
        nodeSurface = BstNode(lower(SurfaceType), ...
                              char(sSubject.Surface(iSurface).Comment), ...
                              char(sSubject.Surface(iSurface).FileName), ...
                              iSurface, iSubject);
        % If current item is default one
        if ismember(iSurface, sSubject.(['i' SurfaceType]))
            nodeSurface.setMarked(1);
        end
        nodeSubject.add(nodeSurface);
    end
end


