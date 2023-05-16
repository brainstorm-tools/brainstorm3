function isOk = tess_bem(iSubject, BemOptions, DEBUG)
% TESS_BEM: Reconstruct 3 layers of BEM surfaces based on cortex+scalp envelopes
%
% USAGE:  tess_bem(iSubject, BemOptions)
%         tess_bem(iSubject)
%
% INPUTS: 
%    - iSubject  : Indice of the subject to process in database
%    - BemOptions: Options structure, with the following fields
%        |- nvert     : [nScalp, nOuterskull, nInnerskull] Number of vertices for each layer
%        |- thickness : [tScalp, tOuterskull, tInnerskull] Relative thickness of each layer
%                      => Values are scaled to the size of the brain/head distance
%
% DESCRIPTION:
%    - Inner skull: 1) Compute the cortex convex envelope for both the subject's and the default anatomies
%                   2) Compute the transformation cortex envelope -> inner skull for the default anatomy
%                   3) Apply the same transformation to the subject's cortex envelope
%                   4) Make sure the distance between the cortex and the inner skull is around 4mm 
%    - Outer skull: Dilatation of 5mm of the inner skull surface
%    - Skin : Re-create the head mask and tesselate its edge

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
% Authors: Francois Tadel, 2011-2012

%% ===== PARSE INPUTS =====
isOk = 0;
if (nargin < 2) || isempty(BemOptions)
    % Ask options to the user
    BemOptions = gui_show_dialog('BEM surfaces options', @panel_bem);
    if isempty(BemOptions)
        return;
    end
end
if (nargin < 3) || isempty(DEBUG)
    DEBUG = 0;
end
% Save current scouts modifications
panel_scout('SaveModifications');
% Get subject
sSubject = bst_get('Subject', iSubject);
% If subject is using the default anatomy: use the default subject instead
if sSubject.UseDefaultAnat
    iSubject = 0;
end
% Check layers
if isempty(sSubject.iCortex) || isempty(sSubject.iScalp) || isempty(sSubject.iAnatomy) || isempty(sSubject.Anatomy)
    error('Computation of BEM layers requires at least: MRI + scalp surface + cortex surface.');
end
% Progress bar
isProgress = bst_progress('IsVisible');
bst_progress('start', 'Create BEM surfaces', 'Initialization...', 0, 100);
% Get surfaces
CortexFile = sSubject.Surface(sSubject.iCortex(1)).FileName;
ScalpFile  = sSubject.Surface(sSubject.iScalp(1)).FileName;


%% ===== GET DEFAULT ANATOMY =====
% Get default anatomy folder
sTemplate = bst_get('AnatomyDefaults', 'ICBM152');
if isempty(sTemplate)
    error('The template anatomy ICBM152 is not available.');
elseif (length(sTemplate) > 1)
    error('Multiple templates "ICBM152" available.');
end
% Get subject file
TemplateCortexFile = bst_fullfile(sTemplate.FilePath, 'tess_cortex_pial_low.mat');
TemplateInnerFile  = bst_fullfile(sTemplate.FilePath, 'tess_innerskull.mat');
TemplateMriFile    = bst_fullfile(sTemplate.FilePath, 'subjectimage_T1.mat');


%% ===== LOAD/CREATE ALL ENVELOPES =====
bst_progress('inc', 10);
% === HEAD ENVELOPE ===
sHead = tess_envelope(ScalpFile, 'mask_head', BemOptions.nvert(1));
if isempty(sHead)
    return;
end
bst_progress('inc', 15);
% === CORTEX ENVELOPE ===
[sCortex, sCortexOrig] = tess_envelope(CortexFile, 'convhull', BemOptions.nvert(3), 0.001);
if isempty(sCortex)
    return;
end
bst_progress('inc', 15);
% === COLIN CORTEX ENVELOPE ===
sTemplateCortex = tess_envelope(TemplateCortexFile, 'convhull', BemOptions.nvert(3), 0.001, TemplateMriFile);
if isempty(sTemplateCortex)
    return;
end
bst_progress('inc', 15);
% === COLIN INNER SKULL ===
bst_progress('text', 'BEM: Reading template inner skull surface...');
bst_progress('inc', 10);
sTemplateInner = in_tess_bst(TemplateInnerFile, 0);
% Downsample template inner skull if necessary
if (length(sTemplateInner.Vertices) > 3000)
    ratio = 1000 ./ length(sTemplateInner.Vertices);
    [sTemplateInner.Faces, sTemplateInner.Vertices] = reducepatch(sTemplateInner.Faces, sTemplateInner.Vertices, ratio);
end


%% ===== PARAMETRIZE CORTEX SURFACES =====
% Align all the surfaces in the normalized coordinates system (AC-PC)
bst_progress('text', 'BEM: Creating spherical parametrizations...');
bst_progress('inc', 5);
vHead        = bst_bsxfun(@minus, sHead.Vertices,        sCortex.center)      * sCortex.R;
vCortex      = bst_bsxfun(@minus, sCortex.Vertices,      sCortex.center)      * sCortex.R;
% vCortexOrig  = bst_bsxfun(@minus, sCortexOrig.Vertices,  sCortex.center)      * sCortex.R;
vTemplateCortex = bst_bsxfun(@minus, sTemplateCortex.Vertices, sTemplateCortex.center) * sTemplateCortex.R;
vTemplateInner  = bst_bsxfun(@minus, sTemplateInner.Vertices,  sTemplateCortex.center) * sTemplateCortex.R;

% Parametrize the surfaces
p   = .2;   % Padding
th  = -pi-p   : 0.01 : pi+p;
phi = -pi/2-p : 0.01 : pi/2+p;
rCortex      = tess_parametrize(vCortex,      th, phi);
rTemplateCortex = tess_parametrize(vTemplateCortex, th, phi);


%% ===== SURFACE ALIGNMENT =====
% Find the max radius for the mid-sagittal plane (phi=0)
iThMax = bst_closest(th, 0);
[rMax,iPhiMax] = max(rCortex(:,iThMax));
[vMax(1),vMax(2),vMax(3)] = sph2cart(th(iThMax), phi(iPhiMax), rMax);
% Find the max radius for the mid-sagittal plane (phi=pi)
iThMin = bst_closest(th, pi);
[rMin,iPhiMin] = max(rCortex(:,iThMin));
[vMin(1),vMin(2),vMin(3)] = sph2cart(th(iThMin), phi(iPhiMin), rMin);
% Same for colin cortex
[rMax_c,iPhiMax_c] = max(rTemplateCortex(:,iThMax));
[vMax_c(1),vMax_c(2),vMax_c(3)] = sph2cart(th(iThMax), phi(iPhiMax_c), rMax_c);
[rMin_c,iPhiMin_c] = max(rTemplateCortex(:,iThMin));
[vMin_c(1),vMin_c(2),vMin_c(3)] = sph2cart(th(iThMin), phi(iPhiMin_c), rMin_c);

% Compute rotation around y axis
u = (vMax_c - vMin_c);
v = (vMax - vMin);
u = u([1 3]) ./ norm(u([1 3]));
v = v([1 3]) ./ norm(v([1 3]));
ay = atan2(v(2),v(1)) - atan2(u(2),u(1));
R_c = [cos(ay) 0 -sin(ay);
          0    1    0    ;
       sin(ay) 0  cos(ay)];
% Reorient template surfaces
vTemplateCortex = vTemplateCortex * R_c';
vTemplateInner  = vTemplateInner * R_c';
vMin_c = vMin_c * R_c';
vMax_c = vMax_c * R_c';

% Get bounding boxes for the 2 cortices
minv = min(vCortex);
maxv = max(vCortex);
minv_c = min(vTemplateCortex);
maxv_c = max(vTemplateCortex);
scale = (maxv-minv) ./ (maxv_c-minv_c);
offset = minv - minv_c .* scale;
% Force the template surfaces to fit into the subject box
vTemplateCortex = bst_bsxfun(@times, vTemplateCortex, scale);
vTemplateCortex = bst_bsxfun(@plus,  vTemplateCortex, offset);
vTemplateInner  = bst_bsxfun(@times, vTemplateInner, scale);
vTemplateInner  = bst_bsxfun(@plus,  vTemplateInner, offset);
vMin_c = vMin_c .* scale + offset; 
vMax_c = vMax_c .* scale + offset; 


%% ===== INTERMEDIATE DEBUG DISPLAY =====
if DEBUG
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(vCortex, sCortex.Faces, .7, [1 0 0]);
    set(hPatch, 'EdgeColor', [1 0 0]);
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(vTemplateCortex, sTemplateCortex.Faces, .7, [0 1 0], hFig);
    set(hPatch, 'EdgeColor', [0 1 0]);
    line(vMin(1), vMin(2), vMin(3), 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 9);
    line(vMax(1), vMax(2), vMax(3), 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 9);
    line(vMin_c(1), vMin_c(2), vMin_c(3), 'Marker', 'o',  'MarkerFaceColor', [0 1 0], 'MarkerSize', 9);
    line(vMax_c(1), vMax_c(2), vMax_c(3), 'Marker', 'o',  'MarkerFaceColor', [0 1 0], 'MarkerSize', 9);
    drawnow
end

%% ===== PARAMETRIZE ALL SURFACES =====
% Parametrize the surfaces
% p   = .2;   % Padding
% th  = -pi-p   : 0.01 : pi+p;
% phi = -pi/2-p : 0.01 : pi/2+p;
rHead        = tess_parametrize(vHead,        th, phi);
rCortex      = tess_parametrize(vCortex,      th, phi);
rTemplateCortex = tess_parametrize(vTemplateCortex, th, phi);
rTemplateInner  = tess_parametrize(vTemplateInner,  th, phi);


%% ===== COMPUTE LAYER SIZES =====
bst_progress('text', 'BEM: Creating skull surfaces...');
% Head radius: Average radius in the top part of the head
iTopVert = (vHead(:,3) > 0);
radiusHead = mean(sqrt(sum(vHead(iTopVert,:).^2, 2)));
% Cortex radius: Average radius in the top part of the head
iTopVert = (vCortex(:,3) > 0);
radiusCortex = mean(sqrt(sum(vCortex(iTopVert,:).^2, 2)));
% Compute the erosions/dilatations values in meters, scaled by the size of current head
relLayerSize = BemOptions.thickness ./ sum(BemOptions.thickness);
layerSize = relLayerSize .* (radiusHead - radiusCortex);


%% ===== INNER/OUTER SKULL =====
% Inner skull: Apply colin cortex->innerskull transformation to subject's cortex
cortex2inner = rTemplateInner ./ rTemplateCortex;
rInner = rCortex .* cortex2inner;
% Limit growth of the inner skull with the head
iFix = find(rInner > rHead - layerSize(2) - layerSize(1));
rInner(iFix) = rHead(iFix) - layerSize(2) - layerSize(1);
% Force inner skull to include all the cortex
rInner = max(rInner, rCortex + 0.001);
% Grow head so that there is at least 2mm between the inner skull and the head
rHead = max(rHead, rInner + 0.002);
% Outer skull: Dilate inner skull, constrain with head
rOuter = min(rInner + layerSize(2), rHead - 0.001);

% Reinterpolate to get inner skull surface based on cortex surface
[thInner,phiInner] = cart2sph(vCortex(:,1), vCortex(:,2), vCortex(:,3));
rInner = interp2(th, phi, rInner, thInner, phiInner);
[vInner(:,1), vInner(:,2), vInner(:,3)] = sph2cart(thInner, phiInner, rInner);
% Reinterpolate to get outer skull surface
rOuter = interp2(th, phi, rOuter, thInner, phiInner);


% ===== DEFORM INNER SKULL TO INCLUDE CORTEX =====
% bst_progress('text', 'BEM: Deforming inner skull...');
% % Dilate a bit the cortex (1 mm), to make sure all the sources are at least further than 1mm from the inner skull
% [thCortexOrig, phiCortexOrig, rCortexOrig] = cart2sph(vCortexOrig(:,1), vCortexOrig(:,2), vCortexOrig(:,3));
% [vCortexOrig(:,1), vCortexOrig(:,2), vCortexOrig(:,3)] = sph2cart(thCortexOrig, phiCortexOrig, rCortexOrig + 0.001);
% % Get convex hull of the dilated cortex: if the convex hull is in the inner skull, the full cortex is too
% fConvHull = convhulln(vCortexOrig);
% iConvHull = unique(fConvHull);
% vCortexOrig = vCortexOrig(iConvHull, :);
% % Look for points of the cortex inside the innerskull
% iVertOut = find(~inpolyhd(vCortexOrig, vInner, sCortex.Faces));
% % Fix point by point
% for i = 1:length(iVertOut)
%     P = vCortexOrig(iVertOut(i),:);
%     % While point is still outside: loop
%     while ~inpolyhd(P, vInner, sCortex.Faces)
%         % Find the two closest vertex of the inner skull
%         [dist, iSort] = sort(sum(bst_bsxfun(@minus, vInner, P).^2, 2));
%         % Increase the radius for the closest points
%         nclose = 4;
%         iv = iSort(1:nclose);
%         d = dist(1:nclose);
%         inc = .001 .* (1-d/norm(d));
%         rInner(iv) = rInner(iv) + inc;
%         rOuter(iv) = rOuter(iv) + inc;
%         % Recompute cartesian coordinates of the vertices
%         [vInner(iv,1), vInner(iv,2), vInner(iv,3)] = sph2cart(thInner(iv), phiInner(iv), rInner(iv));
%     end
%     [hFig, iDS, iFig, hPatch] = view_surface_matrix(vInner, sCortex.Faces, .1, []);
%     set(hPatch, 'EdgeColor', [0 1 0]);
%     line(vCortexOrig(iVertOut,1), vCortexOrig(iVertOut,2), vCortexOrig(iVertOut,3), 'LineStyle', 'none', 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 6);
% end
% ========================================================

% Recompute cartesian coordinates of the outer skull
[vOuter(:,1), vOuter(:,2), vOuter(:,3)] = sph2cart(thInner, phiInner, rOuter);


% === RE-MESH OUTER SKULL ===
if (BemOptions.nvert(2) ~= BemOptions.nvert(3))
    [vOuter, sOuter.Faces] = tess_remesh(vOuter, BemOptions.nvert(2));
else
    sOuter.Faces = sCortex.Faces;
end

% === DEFORM HEAD TO INCLUDE OUTER SKULL ===
bst_progress('text', 'BEM: Deforming head...');
% Parametrize outer skull
%rOuter = tess_parametrize(vOuter, th, phi);
% Grow head so that it is not intersecting the outerskull
%rHead = max(rHead, rOuter + .004);
% Reinterpolate to get head surface based on cortex surface
[thHead,phiHead] = cart2sph(vHead(:,1), vHead(:,2), vHead(:,3));
rHead = interp2(th, phi, rHead, thHead, phiHead);
[vHead(:,1), vHead(:,2), vHead(:,3)] = sph2cart(thHead, phiHead, rHead);

% Reproject into intial coordinates system
sInner.Vertices = bst_bsxfun(@plus, vInner * inv(sCortex.R), sCortex.center);
sOuter.Vertices = bst_bsxfun(@plus, vOuter * inv(sCortex.R), sCortex.center);
sHead.Vertices  = bst_bsxfun(@plus, vHead  * inv(sCortex.R), sCortex.center);
sInner.Faces = sCortex.Faces;


%% ===== SAVE FILES =====
bst_progress('text', 'BEM: Saving new files...');
bst_progress('inc', 10);
% Create output filenames
ProtocolInfo = bst_get('ProtocolInfo');
SurfaceDir   = bst_fullfile(ProtocolInfo.SUBJECTS, bst_fileparts(CortexFile));
BemHeadFile  = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_head_bem_%dV.mat', length(sHead.Vertices))));
BemOuterFile = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_outerskull_bem_%dV.mat', length(sOuter.Vertices))));
BemInnerFile = file_unique(bst_fullfile(SurfaceDir, sprintf('tess_innerskull_bem_%dV.mat', length(sInner.Vertices))));
% Save head
sHead.Comment = sprintf('bem_head_%dV', length(sHead.Vertices));
sHead = bst_history('add', sHead, 'bem', 'BEM surface computed with brainstorm');
bst_save(BemHeadFile, sHead, 'v7');
db_add_surface( iSubject, BemHeadFile, sHead.Comment);
bst_progress('inc', 5);
% Save outerskull
sOuter.Comment = sprintf('bem_outerskull_%dV', length(sOuter.Vertices));
sOuter = bst_history('add', sOuter, 'bem', 'BEM surface computed with brainstorm');
bst_save(BemOuterFile, sOuter, 'v7');
db_add_surface( iSubject, BemOuterFile, sOuter.Comment);
bst_progress('inc', 5);
% Save innerskull
sInner.Comment = sprintf('bem_innerskull_%dV', length(sInner.Vertices));
sInner = bst_history('add', sInner, 'bem', 'BEM surface computed with brainstorm');
bst_save(BemInnerFile, sInner, 'v7');
db_add_surface( iSubject, BemInnerFile, sInner.Comment);
bst_progress('inc', 5);


%% ===== DEBUG DISPLAY =====
if DEBUG
    % Display all the layers
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(sInner.Vertices, sInner.Faces, .7, [0 1 0]);
    set(hPatch, 'EdgeColor', [0 1 0]);
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(sHead.Vertices, sHead.Faces, .8, [0 0 1], hFig);
    set(hPatch, 'EdgeColor', [0 0 1]);
    [hFig, iDS, iFig, hPatch] = view_surface_matrix(sOuter.Vertices, sOuter.Faces, .8, [0 1 1], hFig);
    set(hPatch, 'EdgeColor', [0 1 1]);
%     % Display cortex and innerskull
%     [hFig, iDS, iFig, hPatch] = view_surface_matrix(sCortexOrig.Vertices, sCortexOrig.Faces, 0, [.8 0 0]);
%     [hFig, iDS, iFig, hPatch] = view_surface_matrix(sInner.Vertices, sInner.Faces, 0, [], hFig);
end

% Close, success
if ~isProgress
    bst_progress('stop');
end
isOk = 1;

end