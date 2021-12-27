function [selCond, iStudy] = gui_select_condition(iSubject, iDefaultStudy)
% GUI_SELECT_CONDITION: Offers a list with the available conditions
%
% USAGE:  selCond = gui_select_condition(iSubject, iDefaultStudy);
%         selCond = gui_select_condition(iSubject);
%         selCond = gui_select_condition();

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
% Authors: Francois Tadel, 2008-2010

% Parse inputs
if (nargin < 2)
    iDefaultStudy = [];
end
if (nargin < 1)
    iSubject = [];
end
iStudy = [];
% Get studies
if isempty(iSubject)
    % Get all the studies in database
    ProtocolStudies = bst_get('ProtocolStudies');
    sStudies = ProtocolStudies.Study;
    iStudies = 1:length(sStudies);
    clear ProtocolStudies;
else
    % Get the subject
    sSubject = bst_get('Subject', iSubject);
    % Get all the studies for this subject
    [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
end

% Default condition
if ~isempty(iDefaultStudy)
    % Add default condition on top of the list
    strDefault = '(same folder)';
    condList = {strDefault};
    % Remove default condition from the lists
    is = find(iStudies == iDefaultStudy);
    if ~isempty(is)
        iStudies(is) = [];
        sStudies(is) = [];
    end
else
    condList = {};
end
    
% Get all the conditions from all the studies
for i = 1:length(sStudies)
    % No condition: ignore
    if isempty(sStudies(i).Condition)
        continue;
    end
    % Keep only the non-special and non-raw conditions
    cond = sStudies(i).Condition{1};
    if ~isempty(cond) && ~ismember(cond, {bst_get('DirAnalysisIntra'), bst_get('DirAnalysisInter'), bst_get('DirDefaultStudy')}) && ...
        ~((length(cond) > 4) && strcmpi(cond(1:4), '@raw')) && ...
        ~ismember(cond, condList)
        condList{end+1} = cond;
    end
end

% Create a dialog message
if ~isempty(condList)
    jCombo = gui_component('ComboBox', [], [], [], {condList}, [], [], []);
else
    jCombo = gui_component('ComboBox', [], [], [], [], [], [], []);
end
jCombo.setEditable(1);
message = javaArray('java.lang.Object',2);
message(1) = java.lang.String('<HTML>Select a condition to save the new file:<BR><BR>');
message(2) = jCombo;
% Show question
res = java_call('javax.swing.JOptionPane', 'showConfirmDialog', 'Ljava.awt.Component;Ljava.lang.Object;Ljava.lang.String;I', [], message, 'Select condition', javax.swing.JOptionPane.OK_CANCEL_OPTION);
if (res ~= javax.swing.JOptionPane.OK_OPTION)
    selCond = [];
    return;
end
% Get new condition name
selObj = jCombo.getSelectedObjects();
selCond = char(selObj(1));

% Get study
if ~isempty(iSubject)
    % No input: return nothing
    if isempty(selCond)
        return
    % Default condition is selected
    elseif ~isempty(iDefaultStudy) && strcmpi(selCond, strDefault)
        iStudy = iDefaultStudy;
        sStudy = bst_get('Study', iDefaultStudy);
        selCond = sStudy.Condition{1};
    % If condition does not exist for a subject: create it
    elseif ~ismember(selCond, condList)
        % Try to create condition
        iStudy = db_add_condition(sSubject.Name, selCond);
        % If no condition created
        if isempty(iStudy)
            selCond = [];
            return;
        end
    % Else: Get condition
    else
        % Try to get condition
        [sStudy, iStudy] = bst_get('StudyWithCondition', bst_fullfile(sSubject.Name, selCond));
    end
end


end
