function [SrcLoc, SrcOri, sScout, iVertModif] = dba_get_model( sScout, sCortex )
% Get the grid of source points (position+orientation) for a given brain region.
%
% Yohan Attal, Francois Tadel - HM-TC project 2013

% Vertex indices
iVert = sScout.Vertices;
% If soome vertices are removed from the original scout, the modified version is saved in this variable
iVertModif = [];
% Check depending on the region name
switch sScout.Label
    case {'Accumbens L','LAcc','Accumbens R','RAcc'}
        regionType   = 'vol';
        regionOrient = 'random';
        
    case {'Amygdala L','LAmy','LAmy L','Amygdala R','RAmy','RAmy R'}
        regionType   = 'vol';
        regionOrient = 'random';
        
    case 'Brainstem'
        regionType   = 'vol';
        regionOrient = 'random';
        
    case {'Caudate L','LCau','Caudate R','RCau'}
        regionType   = 'vol';
        regionOrient = 'random';
        
    case {'Cerebellum L','LCer','Cerebellum R','RCer'}
        regionType   = 'surf';
        regionOrient = 'normal';
        
    case {'Hippocampus L','LHip','LHip L','Hippocampus R','RHip','RHip R'}
        regionType   = 'surf';
        regionOrient = 'normal';
        
    case {'Pallidum L','LEgp', 'LIgp','Pallidum R','REgp', 'RIgp'}
        regionType   = 'vol';
        regionOrient = 'y';
        
    case {'Putamen L','LPut','Putamen R','RPut'}
        regionType   = 'vol';
        regionOrient = 'random';
        
    case {'Thalamus L','LTha','Thalamus R','RTha'}
        regionType   = 'vol';
        regionOrient = 'random';
        
    case {'LLgn','RLgn'}
        regionType   = 'vol';
        regionOrient = 'y';
        
    case {'lh', '01_Lhemi L', 'Cortex L', 'rh', '01_Rhemi R', 'Cortex R'}
        % Remove "center-sources" that are not neurones locations using freesurfer Desikan-Killian atlas
        iAtlas_fs = find(strcmpi({sCortex.Atlas.Name}, 'Desikan-Killiany'));
        if ~isempty(iAtlas_fs)
            % Get all the indices present in the atlas: vertices that are not present are in the corpus callosum
            iVertNew = intersect(iVert, [sCortex.Atlas(iAtlas_fs).Scouts.Vertices]);
            % If there are modifications to the list of vertices, they have to be reported in the source model atlas
            if ~isempty(iVertNew)
                iVert      = iVertNew;
                iVertModif = iVertNew;
            end
        end
        regionType   = 'surf';
        regionOrient = 'normal';
        
    otherwise
        regionType = 'surf';
        regionOrient = 'normal';
end

% Get source locations
SrcLoc = dba_anatmodel(iVert, sScout, sCortex, regionType);
% Get orientations
if isequal(sScout.Region(3),'C') || isequal(sScout.Region(3),'L') % fixed or loose orientation orientation
    SrcOri = dba_elecmodel(regionOrient, iVert, sScout, sCortex, SrcLoc );
else
    SrcOri = 0 * SrcLoc;
end
% Update scouts structure
if strcmpi(regionType, 'vol')
    sScout.Region(2) = 'V';
else
    sScout.Region(2) = 'S';
end




