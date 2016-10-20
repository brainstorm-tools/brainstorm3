function sourceLoc = dba_anatmodel(ind, sScout, CortexMat, srcType)
% 
% Compute sources locations for deep structures
% 
% Yohan Attal - HM-TC project 2013

disp = 0;

switch srcType
    case 'surf'        
        sourceLoc = CortexMat.Vertices(ind,:);
        
    case 'vol'
        [ind_s, I_ind] = sort(ind);
        vertTmp = CortexMat.Vertices(sScout.Vertices,:);        
        tessTmp.Vertices = vertTmp(I_ind,:);
        iFaces = sum(ismember(CortexMat.Faces, ind_s),2)==3;
        tessTmp.Faces = CortexMat.Faces(iFaces,:);
        for iv=1:numel(tessTmp.Faces)
            tessTmp.Faces(iv) = find(ind_s==tessTmp.Faces(iv));
        end
        sourceLoc = dba_vol_grids(tessTmp);
end
if disp && isequal(srcType,'vol')
    figure('color','w'); hold on; pp = patch(tessTmp);
    set(pp, 'FaceColor', [0 0 1] , 'FaceAlpha', .5, 'EdgeAlpha', 0)
    plot3(sourceLoc(:,1), sourceLoc(:,2),sourceLoc(:,3),'ro')
end
end