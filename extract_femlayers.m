
function NewFile = extract_femlayers(iSubject, FemFile)

    % Ask user to select the layer to refine with panel_femselect
    OPTIONS = gui_show_dialog('Refine FEM mesh', @panel_femselect, 1, [], FemFile);
    
    % Load FEM mesh
    bst_progress('start', 'Convert FEM mesh', ['Loading file: "' FemFile '"...']);
    FemFile = file_fullpath(FemFile);
    FemMat = load(FemFile);
    
    % Get tissues marked
    selectedTissue = find(OPTIONS.LayerSelect);
    selectedElementIndex = [];
    tissueId = [];
    tissueLabel = {};
    if ~isempty(selectedTissue)
        for iTissue = 1 : length(selectedTissue)
            tmpIndx = find(FemMat.Tissue == selectedTissue(iTissue));
            selectedElementIndex = [selectedElementIndex; tmpIndx];
            tissueId = [tissueId; repmat(iTissue, length(tmpIndx),1)];
            tissueLabel{iTissue} =  FemMat.TissueLabels{selectedTissue(iTissue)};
        end
    end
    NewElem = FemMat.Elements(selectedElementIndex, :);
    [NewNode, NewElem] = removeisolatednode(FemMat.Vertices, [NewElem tissueId]);
    % figure; plotmesh(NewNode, NewElem, 'x>0')
    FemMat.Vertices = NewNode;
    FemMat.Elements = NewElem(:, 1:4);
    FemMat.Tissue = tissueId;
    FemMat.TissueLabels = tissueLabel;
     % Edit file comment: number of layers
    oldNlayers = regexp(FemMat.Comment, '\d+ layers', 'match');
    if ~isempty(oldNlayers)
        FemMat.Comment = strrep(FemMat.Comment, oldNlayers{1}, sprintf('%d layers', length(FemMat.TissueLabels)));
    else
        FemMat.Comment = sprintf('%s (%d layers)', str_remove_parenth(FemMat.Comment), length(FemMat.TissueLabels));
    end
    % Edit file comment: number of nodes
    oldNvert = regexp(FemMat.Comment, '\d+V', 'match');
    if ~isempty(oldNvert)
        FemMat.Comment = strrep(FemMat.Comment, oldNvert{1}, sprintf('%dV', size(FemMat.Vertices, 1)));
    end
    
    % Output filename
    [fPath, fBase, fExt] = bst_fileparts(FemFile);
    NewFile = file_unique(bst_fullfile(fPath, [fBase, '_merge', fExt]));
    % Save new surface in Brainstorm format
    bst_progress('text', 'Saving new mesh...');
    bst_save(NewFile, FemMat, 'v7');
    % Add to database
    % [sSubject, iSubject] = bst_get('SurfaceFile', FemFile);
    db_add_surface(iSubject, NewFile, FemMat.Comment);
    
    % Close progress bar
    bst_progress('stop');
end



