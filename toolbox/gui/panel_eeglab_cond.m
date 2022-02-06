function varargout = panel_eeglab_cond(varargin)
% PANEL_EEGLAB_COND: Selection of conditions from EegLab .set files.
%
% USAGE:  bstPanelNew = panel_eeglab_cond('CreatePanel', panelName)
%           selParams = panel_eeglab_cond('GetSelectedParameters')
%        selectedCond = panel_eeglab_cond('GetPanelContents')

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
% Authors: Francois Tadel, 2008-2017

eval(macro_method);
end


%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel(paramNames, paramValues) %#ok<DEFNU>
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import javax.swing.table.*; 
    import org.brainstorm.table.*;
    panelName = 'EeglabConditions';

    % Create panel
    jPanelNew = gui_component('Panel');
    
    % ===== PARAMETERS LIST =====
    jPanelParams = gui_component('Panel');
    jBorder = java_scaled('titledborder', 'Parameters');
    jPanelParams.setBorder(jBorder);
            
    jPanelParams.setPreferredSize(java_scaled('dimension', 110, 200));
        % JList
        jListParams = JList(paramNames);
        jListParams.setFont(bst_get('Font'));
        java_setcb(jListParams, 'ValueChangedCallback', @ParamSelectionChanged_Callback);
        % Create scroll panel
        jScrollPanelParams = JScrollPane(jListParams);
        jScrollPanelParams.setBorder([]);
        jPanelParams.add(jScrollPanelParams, BorderLayout.CENTER);
    jPanelNew.add(jPanelParams, BorderLayout.WEST);
    
    % ===== CONDITIONS NAMES =====
    jPanelCond = gui_component('Panel');
    jBorder = java_scaled('titledborder', 'Conditions');
    jPanelCond.setBorder(jBorder);
    jPanelCond.setPreferredSize(java_scaled('dimension', 400, 200));
        % JTable 
        jTableCond = JTable(DefaultTableModel({'Parameters', 'Condition name'}, 0));
        jTableCond.setFont(bst_get('Font'));
        jTableCond.getColumnModel.getColumn(0).setCellEditor(DisabledCellEditor());
        % Create scroll panel
        jScrollPanelCond = JScrollPane(jTableCond);
        jScrollPanelCond.setBorder([]);
        jPanelCond.add(jScrollPanelCond, BorderLayout.CENTER);
    jPanelNew.add(jPanelCond, BorderLayout.CENTER);
    
    % ===== VALIDATION BUTTONS =====
    jPanelValidation = gui_river([5,5], [0,5,12,5]);    
        % Cancel
        jButtonCancel = JButton('Cancel');
        java_setcb(jButtonCancel, 'ActionPerformedCallback', @ButtonCancel_Callback);
        jPanelValidation.add('br right', jButtonCancel);
        % Ok
        jButtonOk = JButton('OK');
        java_setcb(jButtonOk, 'ActionPerformedCallback', @ButtonOk_Callback);
        jPanelValidation.add(jButtonOk);
    jPanelNew.add(jPanelValidation, BorderLayout.SOUTH);
    
    % Return a mutex to wait for panel close
    bst_mutex('create', panelName);

    % Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jListParams', jListParams, ...
                                  'jTableCond',  jTableCond));
          
                              
                              
%% =================================================================================
%  === LOCAL CALLBACKS =============================================================
%  =================================================================================               
%% ===== CANCEL =====
    function ButtonCancel_Callback(varargin)
        % Close panel
        gui_hide(panelName);
    end

%% ===== OK =====
    function ButtonOk_Callback(varargin)
        % Close cell editor (validate last edited string)
        cellEditor = jTableCond.getCellEditor();
        if ~isempty(cellEditor)
        	cellEditor.stopCellEditing();
        end
        % Release mutex and keep the panel opened
        bst_mutex('release', panelName);
    end

%% ===== SELECTION CHANGED =====
    function ParamSelectionChanged_Callback(hObject, ev)
        global combinCond;
        if ~ev.getValueIsAdjusting()
            % Get selected items
            iSel = double(jListParams.getSelectedIndices());
            % Update JList conditions list
            tableModel = jTableCond.getModel();
            tableModel.setRowCount(0);
            % Check number of final combinations
            nbCond = prod(cellfun(@length, paramValues(iSel+1)));
%             % Too many combinations
%             if (nbCond > 500)
%                 combinCond = [];
%                 tableModel.addRow({'(Error: too many combinations)', ''});
%             else
                % Compute a structure that describes all the combinations
                combinCond = GetConditionCombinations(paramNames(iSel+1), paramValues(iSel+1));
                % Process all the combinations
                params = paramNames(iSel+1);
                for iCond = 1:length(combinCond)
                    strCondName = '';
                    strParamList = '';
                    for iParam = 1:length(params)
                        if (iParam ~= 1)
                            strCondName = [strCondName '_'];
                            strParamList = [strParamList, ', '];
                        end
                        if ischar(combinCond(iCond).(params{iParam}))
                            tmpStr = strrep(file_standardize(combinCond(iCond).(params{iParam})), '_', '-');
                            strCondName  = [strCondName, params{iParam}, tmpStr];
                            strParamList = [strParamList, params{iParam}, '=', combinCond(iCond).(params{iParam})];
                        else
                            strCondName  = [strCondName, params{iParam}, sprintf('%d', combinCond(iCond).(params{iParam}))];
                            strParamList = [strParamList, params{iParam}, sprintf('=%d', combinCond(iCond).(params{iParam}))];
                        end
                    end
                    tableModel.addRow({strParamList, strCondName});
                end
%             end
        end
    end
end


%% =================================================================================
%  === EXTERNAL CALLBACKS ==========================================================
%  =================================================================================
%% ===== GET SELECTED PARAMETERS =====
function selParams = GetSelectedParameters() %#ok<DEFNU>
    ctrl = bst_get('PanelControls', 'EeglabConditions');
    selObj = ctrl.jListParams.getSelectedValues();
    selParams = cell(1, length(selObj));
    for i = 1:length(selObj)
        selParams{i} = char(selObj(i));
    end
end

%% ===== GET PANEL RESULTS =====
function selectedCond = GetPanelContents(varargin) %#ok<DEFNU>
    % Get panel controls
    ctrl = bst_get('PanelControls', 'EeglabConditions');
    if isempty(ctrl)
        selectedCond = [];
        return
    end
    % Get current combination description
    global combinCond;
    selectedCond = combinCond;
    combinCond = [];
    clear global combinCond;
    % If nothing is available
    if (length(selectedCond) < 2)
        selectedCond = [];
    else
        % Get selected indices
        iCondSel = ctrl.jTableCond.getSelectedRows();
        if ~isempty(iCondSel)
            iCondSel = double(iCondSel(:))' + 1;
        else
            iCondSel = 1:length(selectedCond);
        end
        % Read new conditions names
        for iCond = iCondSel
            selectedCond(iCond).Name = file_standardize(char(ctrl.jTableCond.getModel.getValueAt(iCond-1, 1)));
        end
        selectedCond = selectedCond(iCondSel);
    end
end



%% =================================================================================
%  === HELPERS =====================================================================
%  =================================================================================
function combinCond = GetConditionCombinations(paramName, paramValues)
    % Get final number of conditions
    nbValues = cellfun(@length, paramValues);
    nbCond = prod(nbValues);
    % Build structure returned for each conditions
    structCond = struct('Name', '');
    for iField = 1:length(paramName)
        structCond.(paramName{iField}) = [];
    end   
    combinCond = repmat(structCond, 1, nbCond);
    % Process each condition
    for iCond = 1:nbCond
        iValues = my_ind2sub(nbValues, iCond);
        % Process each parameter
        for iParam = 1:length(paramValues)
            % Get the value for parameter
            if iscell(paramValues{iParam})
                combinCond(iCond).(paramName{iParam}) = paramValues{iParam}{(iValues(iParam))};
            else
                combinCond(iCond).(paramName{iParam}) = paramValues{iParam}((iValues(iParam)));
            end
        end
    end
end


%% ===== CONVERT INDICES TO SUBINDICES =====
function loc = my_ind2sub(siz, ndx)
    n = length(siz);
    k = [1 cumprod(siz(1:end-1))];
    loc = zeros(size(siz));
    for i = n:-1:1,
      vi = rem(ndx-1, k(i)) + 1;         
      vj = (ndx - vi)/k(i) + 1; 
      loc(i) = vj; 
      ndx = vi;     
    end
end

    
        
