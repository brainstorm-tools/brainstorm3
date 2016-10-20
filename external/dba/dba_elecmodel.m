function sourceOri = dba_elecmodel(oriType, ind, sScout, CortexMat, sourceLoc)
%
% Compute basic sources orientation for deep structures
%
% Yohan Attal - HM-TC project 2013

disp = 0;

% get mesh
[ind_s, I_ind] = sort(ind);
vertTmp = CortexMat.Vertices(sScout.Vertices,:);
tessTmp.Vertices = vertTmp(I_ind,:);
iFaces = sum(ismember(CortexMat.Faces, ind_s),2)==3;
tessTmp.Faces = CortexMat.Faces(iFaces,:);
for iv=1:numel(tessTmp.Faces)
    tessTmp.Faces(iv) = find(ind_s==tessTmp.Faces(iv));
end
% tessTmp.Vertices = CortexMat.Vertices(sAtlas.Scouts(is).Vertices,:);
% iFaces = sum(ismember(CortexMat.Faces, ind),2)==3;
% facTmp = CortexMat.Faces(iFaces,:);
% tessTmp.Faces = facTmp - min(facTmp(:)) + 1;

% compute orientation using external envellope
switch oriType
    case 'normal'
        sourceOri = CortexMat.VertNormals(ind,:);
    case {'random', 'x', 'y', 'z'}
        sourceOri = dba_ecd_ori(oriType, sourceLoc, tessTmp);
        if disp
            figure('color','w'); hold on; pp = patch(tessTmp);
            set(pp, 'FaceColor', [0 0 1] , 'FaceAlpha', .5, 'EdgeAlpha', 0)
            plot3(sourceLoc(:,1), sourceLoc(:,2),sourceLoc(:,3),'ro')
            quiver3(sourceLoc(:,1), sourceLoc(:,2),sourceLoc(:,3), ...
                sourceOri(:,1), sourceOri(:,2),sourceOri(:,3));
        end
end
end


