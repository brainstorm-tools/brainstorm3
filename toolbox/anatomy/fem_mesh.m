function  fem_mesh(TessFiles)
% FEM_MESH: generate tetrahedral mesh from surface files.
%                       This function calls the iso2mesh toolbox (function surf2mesh and raytrace)
% USAGE:  fem_mesh(TessFiles)
%
%
% INPUT:
%    - TessFiles   : Cell-array of paths to surfaces files to concatenate
% OUTPUT: none (files to database)


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



% Open progress bar
bst_progress('start', 'FEM mesh', 'FEM mesh generation (iso2mesh)...');
Method = 'surf2vol';
% Only tetra could be generated from this method
meshType = 'Tetrahedral';

% Ask BEM meshing options
res = java_dialog('input', {'Max tetrahedral volume (10=coarse, 0.0001=fine):', 'Percentage of elements kept (1-100%):'}, ...
    'FEM mesh', [], {'0.1', '100'});
% If user cancelled: return
if isempty(res)
    return
end
MaxVol    = str2num(res{1});
KeepRatio = str2num(res{2}) ./ 100;
if isempty(MaxVol) || (MaxVol < 0.000001) || (MaxVol > 20) || ...
        isempty(KeepRatio) || (KeepRatio < 0.01) || (KeepRatio > 1)
    bst_error('Invalid ', 'FEM mesh', 0);
    return
end

% Check if iso2mesh is in the path
if ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
    errMsg = InstallIso2mesh(isInteractive);
    if ~isempty(errMsg) || ~exist('iso2meshver', 'file') || ~isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
        return;
    end
end

% Load the surfaces
NumberOfbLayers = length(TessFiles);
newnode = [];
newelem = [];
if NumberOfbLayers == 1 % in the case where only one surface is selected or use the merged surfaces
    FileMat  = in_tess_bst(TessFiles{1});
    newnode = FileMat.Vertices;
    newelem = FileMat.Faces;
    % figure; plotmesh(newnode,newelem,'x>0')    
    % get the name of the merged file
    if length(FileMat.Atlas) == 1 % This is a single file
        [~,name,~] = fileparts(TessFiles{1});
        k = strfind(name,'_');
        if length(k) == 1
            tissu = name(k(1)+1:end);
        else
            tissu = name(k(1)+1:k(2)-1);
        end
        TissueLabels{1} = tissu;
    else % this is a merged files
        TissueLabels = cell(1,length(FileMat.Atlas(2).Scouts));
        for ind = 1 : length(FileMat.Atlas(2).Scouts)
            TissueLabels{ind} = FileMat.Atlas(2).Scouts(ind).Label ;
        end
    end
else % in the case of multiple selection
    for iSurf = 1 : NumberOfbLayers
        FileMat  = in_tess_bst(TessFiles{iSurf});
        node = FileMat.Vertices;
        elem = FileMat.Faces;
        if iSurf == 1
            newnode = node;
            newelem = [elem iSurf*ones(length(elem),1)];
        else
            [newnode,newelem] = mergemesh(newnode,newelem,node, [elem iSurf*ones(length(elem),1)]);
        end
        % figure; plotmesh(newnode,newelem,'x>0')
        [~,name,~] = fileparts(TessFiles{iSurf});
        k = strfind(name,'_');
        if length(k) == 1
            tissu = name(k(1)+1:end);
        else
            tissu = name(k(1)+1:k(2)-1);
        end
        TissueLabels{iSurf} = tissu;
        clear node elem
    end
end
% % remove duplicated node and reorient the mesh
[no,el]=meshcheckrepair(newnode,newelem(:,1:3),'dup');
[no,el]=meshcheckrepair(no,el,'isolated');
% [no,el]=meshcheckrepair(no,el,'isolated');
% [no,el]=meshcheckrepair(no,el,'meshfix');
newnode = no; clear no
newelem = el; clear el;

% figure; plotmesh(newnode,newelem,'x<0'); hold on; plotmesh(orig,'ro','markersize',15)
% define seeds along the v0 axis
orig = mean(newnode);
v0= [0 0 1];
[t,~,~,faceidx]=raytrace(orig,v0,newnode,newelem(:,1:3));
t=sort(t(faceidx));
t=(t(1:end-1)+t(2:end))*0.5;
seedlen=length(t);
regions0=repmat(orig(:)',seedlen,1)+repmat(v0(:)',seedlen,1).*repmat(t(:),1,3);
% Add one more vector with an other orientation  for better distinction (in some case it needed)
v0= [1 1 1];
[t,~,~,faceidx]=raytrace(orig,v0,newnode,newelem(:,1:3));
t=sort(t(faceidx));
t=(t(1:end-1)+t(2:end))*0.5;
seedlen=length(t);
regions1=repmat(orig(:)',seedlen,1)+repmat(v0(:)',seedlen,1).*repmat(t(:),1,3);
regions = [regions0; regions1];

%% Generate volume mesh
% The order is important, the output label will be related to this order,
% which is related to the conductivity value.
clear node elem face;
factor_bst = 1.e-6;
[node,elem,~]=surf2mesh(newnode,newelem,...
    min(newnode),max(newnode),...
    KeepRatio,MaxVol *factor_bst,regions,[]);
figure; plotmesh(node,elem,'x<0'); hold on; plotmesh(orig,'ro','markersize',15)

% Sorting compartments from the center of the head
allLabels = unique(elem(:,5));
dist = zeros(1, length(allLabels));
for iLabel = 1:length(allLabels)
    iElem = find(elem(:,5) == allLabels(iLabel));
    iVert = unique(reshape(elem(iElem,1:4), [], 1));
    dist(iLabel) = min(sum(node(iVert,:) .^ 2,2));
end
[~, I] = sort(dist);
allLabels = allLabels(I);
% Relabelling
elemLabel = ones(size(elem,1),1);
for iLabel = 1:length(allLabels)
    elemLabel((elem(:,5) == allLabels(iLabel))) = iLabel;
end
elem(:,5) = elemLabel;
% % remove duplicated node and reorient the mesh
% [no,el]=meshcheckrepair(node,elem(:,1:4),'dup');
% [no,el]=meshcheckrepair(no,el,'isolated');
% [no,el]=meshcheckrepair(no,el,'meshfix');
% Orientation required for the FEM computation (at least with SimBio, may be not for Duneuro)
newelem = meshreorient(no, el(:,1:4)); clear no  el
elem = [newelem elem(:,5)];
% ===== SAVE FEM MESH =====
% Create output structure
FemMat.Comment = sprintf('FEM %dV (%s , %d layer(s), %s mesh)', length(node), Method, NumberOfbLayers,meshType);
FemMat.Vertices = node;
FemMat.TissueLabels = TissueLabels;

if strcmp(meshType, 'Tetrahedral')
    FemMat.Elements = elem(:,1:4);
    FemMat.Tissue = elem(:,5);
else
    FemMat.Elements = elem(:,1:8);
    FemMat.Tissue = elem(:,9);
end

% Add history
NumberOfbLayers = length( FemMat.TissueLabels);
FemMat = bst_history('add', FemMat, 'fem_mesh', [...
    'Method=',    Method, '|', ...
    'Mesh type =',    meshType, '|', ...
    'Number of layer= ',  num2str(NumberOfbLayers), '|', ...
    'MaxVol=',    num2str(MaxVol),  '|', ...
    'KeepRatio=', num2str(KeepRatio)]);
% Save to database
% ===== SAVE IN DATABASE =====
isSave = 1;
fileTag = 'femMesh';
if isSave
    % Create new filename
    NewTessFile = bst_fullfile(bst_fileparts(TessFiles{1}), ['tess_fem_' fileTag '.mat']);
    FemFile = file_unique(NewTessFile);
    % Save file
    bst_save(FemFile, FemMat, 'v7');    
    % Get subject
    [sSubject, iSubject] = bst_get('SurfaceFile', TessFiles{1});   
    % Make output filename relative
    NewTessFile = file_short(NewTessFile);    
    % Register this file in Brainstorm database
    NewComment = FemMat.Comment;         fileType = 'other';
    iSurface = db_add_surface(iSubject, FemFile, NewComment);
else
    NewTessFile = NewTess;
    iSurface = [];
end
% Close progress bar
bst_progress('stop');
end


%% ===== INSTALL ISO2MESH =====
function errMsg = InstallIso2mesh(isInteractive)
% Initialize variables
errMsg = [];
curdir = pwd;
% Check if already available in path
if exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
    disp([10, 'Iso2mesh path: ', bst_fileparts(which('iso2meshver')), 10]);
    return;
end

% Get default url
osType = bst_get('OsType', 0);
switch(osType)
    case 'linux32',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux32.zip%2Fdownload&ts=1568212532';
    case 'linux64',  url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-linux64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-linux64.zip%2Fdownload&ts=1568212566';
    case 'mac32',    error('MacOS 32bit systems are not supported');
    case 'mac64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-osx64.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-osx64.zip%2Fdownload&ts=1568212596';
    case 'sol64',    error('Solaris system is not supported');
    case 'win32',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
    case 'win64',    url = 'https://downloads.sourceforge.net/project/iso2mesh/iso2mesh/1.9.0-1%20%28Iso2Mesh%202018%29/iso2mesh-2018-win32.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fiso2mesh%2Ffiles%2Fiso2mesh%2F1.9.0-1%2520%2528Iso2Mesh%25202018%2529%2Fiso2mesh-2018-win32.zip%2Fdownload%3Fuse_mirror%3Diweb%26r%3Dhttps%253A%252F%252Fsourceforge.net%252Fprojects%252Fiso2mesh%252Ffiles%252Fiso2mesh%252F1.9.0-1%252520%252528Iso2Mesh%2525202018%252529%252Fiso2mesh-2018-win32.zip&ts=1568212385';
    otherwise,       error('OpenMEEG software does not exist for your operating system.');
end

% Local folder where to install iso2mesh
isoDir = bst_fullfile(bst_get('BrainstormUserDir'), 'iso2mesh', osType);
exePath = bst_fullfile(isoDir, 'iso2mesh', 'iso2meshver.m');
% If dir doesn't exist in user folder, try to look for it in the Brainstorm folder
if ~isdir(isoDir)
    isoDirMaster = bst_fullfile(bst_get('BrainstormHomeDir'), 'iso2mesh');
    if isdir(isoDirMaster)
        isoDir = isoDirMaster;
    end
end

% URL file defines the current version
urlFile = bst_fullfile(isoDir, 'url');
% Read the previous download url information
if isdir(isoDir) && file_exist(urlFile)
    fid = fopen(urlFile, 'r');
    prevUrl = fread(fid, [1 Inf], '*char');
    fclose(fid);
else
    prevUrl = '';
end
% If file doesnt exist: download
if ~isdir(isoDir) || ~file_exist(exePath) || ~strcmpi(prevUrl, url)
    % If folder exists: delete
    if isdir(isoDir)
        file_delete(isoDir, 1, 3);
    end
    % Create folder
    res = mkdir(isoDir);
    if ~res
        errMsg = ['Error: Cannot create folder' 10 isoDir];
        return
    end
    % Message
    if isInteractive
        isOk = java_dialog('confirm', ...
            ['Iso2mesh is not installed on your computer (or out-of-date).' 10 10 ...
            'Download and the latest version of Iso2mesh?'], 'Iso2mesh');
        if ~isOk
            errMsg = 'Download aborted by user';
            return;
        end
    end
    % Download file
    zipFile = bst_fullfile(isoDir, 'iso2mesh.zip');
    errMsg = gui_brainstorm('DownloadFile', url, zipFile, 'Download Iso2mesh');
    % If file was not downloaded correctly
    if ~isempty(errMsg)
        errMsg = ['Impossible to download Iso2mesh:' 10 errMsg1];
        return;
    end
    % Display again progress bar
    bst_progress('text', 'Installing Iso2mesh...');
    % Unzip file
    cd(isoDir);
    unzip(zipFile);
    file_delete(zipFile, 1, 3);
    cd(curdir);
    % Save download URL in folder
    fid = fopen(urlFile, 'w');
    fwrite(fid, url);
    fclose(fid);
end
% If installed but not in path: add to path
if ~exist('iso2meshver', 'file') && isdir(bst_fullfile(bst_fileparts(which('iso2meshver')), 'doc'))
    addpath(bst_fileparts(exePath));
    disp([10, 'Iso2mesh path: ', bst_fileparts(isoDir), 10]);
    % If the executable is still not accessible
else
    errMsg = ['Iso2mesh could not be installed in: ' isoDir];
end
end
