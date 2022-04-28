function [IterationMap,Metrics,err] = bst_connectivity_mra(F, Surface, Options)
% BST_CONNECTIVITY_MRA: Multiresolution analysis of connectivity
%
% USAGE:  [ItMap,Metrics] = bst_connectivity_mra(F, Surface, HeadModel.Gain(Results.GoodChannel,:))
%
% INPUTS: 
%    - F           : N-source x N-sample time-series for analysis 
%    - Surface     : tesselation structure (Faces,Vertices,VertConn)
%    - Options     : N-source gain matrix from the head model
%
% OUTPUTS:
%    - IterationMap  : N-source vector with each number corresponding to
%                      the iteration at which they left the process (indicative
%                      of their probability of high connectivity)
%    - Metrics       : N-iteration cells containing connectivity metric for
%                      each iteration
%    - err           : Error message, if any
%
% NOTE:
%    - Selection model that doesn't work:
%       Using the upper half of subdivision - Weird results
%       Using a high prctile value - Too discriminatory
% 
%    - Selection model that work:
%       Hard threshold works well, but arbitrary threshold
%
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
% Authors: Sebastien Dery, 2013

    Verbose = 0;
    ShuffleVertices = 1;

    nSample = size(F,2);
    nVertices = length(Surface.Vertices);
    % Init varout
    IterationMap = zeros(nVertices,1);
    Metrics = [];
    err = [];
    
    %S1 = extend(3664, sSurf.VertConn, 4);
    %S2 = extend(10588, sSurf.VertConn, 4);
    %Source = [find(S1(3664,:)) find(S2(10588,:))];
    
    isAbsolute = 1;
    nChannel = 272;
    SplitFactor = 2;
    
    % Unconstrained function
    isNorm = 1;
    if isNorm
        XyzFunction = 'norm';
    else
        XyzFunction = 'none';
    end
    ScoutFunction = 'mean';
    nComponents = 1;
    
    % Equal to the number of recorded channel
    nTessScouts = nChannel / SplitFactor;
    
    % Remaining vertices
    RemVert = 1:nVertices;
    % Initial tesselation
    Vert = 1:length(RemVert);
    VertConn = Surface.VertConn(RemVert,RemVert);
    Scouts = tess_cluster_seed(Vert(randperm(length(Vert))), VertConn, nTessScouts);
    
    iter = 1;
    nDipole = round(length(RemVert) / nTessScouts);
    while (nDipole > 2)
        % Switch variable to prevent mixing
        OldScouts = Scouts;
        % Tesselate the scout vertices
        uScouts = unique(OldScouts(OldScouts ~= 0));
        Label = 0;
        for i=1:length(uScouts)
            iRows = find(OldScouts == uScouts(i));
            Scouts(iRows) = tess_cluster(Surface.VertConn(iRows,iRows), SplitFactor, ShuffleVertices, Verbose) + Label;
            Label = Label + 2;
        end
        
        % 
        uScouts = unique(Scouts(Scouts ~= 0));
        nScouts = length(uScouts);
        % 
        Fs = zeros(nScouts, nSample);
        % 
        for i=1:nScouts
            % Get the scout vertices
            iRows = find(Scouts == uScouts(i));
            % Get the scout orientation
            ScoutOrient = Surface.VertNormals(iRows,:);
            % Get scout value
            Fs(i,:) = bst_scout_value(F(iRows,:), ScoutFunction, ScoutOrient, nComponents, XyzFunction);
        end
        
        % Compute normalised distance
        % D = dist(Center');
        % D = (D - min(D(:))) ./ (max(D(:)) - min(D(:)));
        % D = 1 ./ D;
        % Compute metric
        switch (Options.method)
            case 'corr'
                % R = real(bst_corrn(Fs, Fs, inputs.removemean));        
                R = corrcoef([Fs Fs]');
            case 'cohere'
                % R = bst_coherence(Fs, Fs, Options);
                error('Not supported yet.');
            case 'granger'
                R = bst_granger(Fs, Fs, Options.GrangerOrder, Options);
            case 'spgranger'
                error('Not supported yet.');
            case 'plv'
                
            otherwise
        end
        % Remove diagonal
        R(eye(length(R)) == 1) = 0;
        % 
        if isAbsolute
            R = abs(R);
        end
        
        % Higher than mean - Rows 
        tLowCorr = max(R,[],2);
        minCorr = mean(tLowCorr);
        Keep = tLowCorr > minCorr;
        % If directional data, check the other way around
        if (strcmpi(Options.method,'granger') || strcmpi(Options.method,'spgranger'))
            % Higher than mean - Columns
            tLowCorr = max(R);
            minCorr = mean(tLowCorr);
            Keep = Keep | (tLowCorr > minCorr)';
        end
        % Remove everything else
        lRow = find(~Keep);        
        if isempty(lRow)
            break;
        end
        % 
        RowId = ismember(Scouts,lRow);
        % Keep track of when these dipoles left the iteration process
        IterationMap(RemVert(RowId == 1)) = iter;
        % Leave these vertices out
        Scouts(RowId == 1) = 0;
        % Keep metric matrix
        Metrics{iter} = R;
        % Update iterative variables
        nDipole = floor(sum(Scouts ~= 0) / (nScouts - length(lRow)));
        iter = iter + 1;
    end
    % Assign victorious last
    IterationMap(IterationMap == 0) = iter;
end