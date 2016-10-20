
function [ O_hat ] = dba_ecd_ori(archiType, Sourceloc, externalTess )
%
% Compute the ECD orientation from surfacic/volumic geometrical support
% 
% Yohan Attal - HM-TC project 2011


% Orientation following the main inertia axes or randomly distributed ( 3 x NbSources)
switch archiType
    case 'random'
        O = 2*rand(3,length(Sourceloc)) - ones(3,length(Sourceloc));
        
    case 'x'
        [ U ] = dba_coord_axes( externalTess );
        O = repmat([U(1,1);U(2,1);U(3,1)],1,length(Sourceloc));%/3);
        
    case 'y'
        [ U ] = dba_coord_axes( externalTess );
        O = repmat([U(1,2);U(2,2);U(3,2)],1,length(Sourceloc));%/3);
        
    case 'z'
        [ U ] = dba_coord_axes( externalTess );
        O = repmat([U(1,3);U(2,3);U(3,3)],1,length(Sourceloc));%/3);
                
end

% normalize it
O_hat = O * bst_inorcol(O);
O_hat = O_hat'; % NbSources x 3



%% visu
% [hFig, hs] = dba_view_surface_data(externalTess, zeros(length(externalTess.Vertices)), [], jet, 0, '');
% set(hs, 'FaceAlpha', 0.4)
% hold on, set(gcf,'color','w')
% plot3(Sourceloc(:,1),Sourceloc(:,2),Sourceloc(:,3),'ro')
% quiver3(Sourceloc(:,1),Sourceloc(:,2),Sourceloc(:,3),O_hat(:,1),O_hat(:,2),O_hat(:,3),1.5); axis off



