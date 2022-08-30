function [stable, transient, stablePoints, transientPoints, dEnergy] = ...
      bst_opticalflow_states(flowField, Faces, Vertices, dimension, interval, samplingInterval, displayFlag)
% BST_OPTICALFLOW_STATES  Computation of stable and transition states for
%                         optical flow (i.e. points where flow is strongest
%                         and weakest).
% INPUTS:
%   flowField           - Optical flow displacment field
%   Faces               - Faces of tesselation
%   Vertices            - Vertices of tesselation
%   dimension           - 3 for reconstructions, 2 for projections
%   interval            - time points for which flow is calculated
%   samplingInterval    - time between two samples, used to remove
%                         fake microstates (with duration < 5ms)
%   displayFlag         - flag to display displacement energy with time
%                             points labeled if they are part of a stable
%                             or transition state
% OUTPUTS:
%   stable              - List where each row is a 2-element pair
%                         containing the start and stop of a stable state
%   transient           - List where each row is a 2-element pair
%                         containing the start and stop of a fast state
%   stablePoints        - All times during which flow is "stable"
%   transientPoints     - All times during which flow is "fast"
%   dEnergy             - displacement energy in flow

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

% Setup: get displacement energy
[syed, triangleAreas] = geometry_tesselation(Faces, Vertices, dimension);
dEnergy = zeros(1, size(flowField,3));
for m = 1:size(flowField,3);
  v12 = sum((flowField(Faces(:,1),:,m)+flowField(Faces(:,2),:,m)).^2,2) / 4;
  v23 = sum((flowField(Faces(:,2),:,m)+flowField(Faces(:,3),:,m)).^2,2) / 4;
  v13 = sum((flowField(Faces(:,1),:,m)+flowField(Faces(:,3),:,m)).^2,2) / 4;
  dEnergy(m) = sum(triangleAreas.*(v12+v23+v13));
end
dEnergy = sqrt(dEnergy); % Get square root for easier visualization

% Find local minima
minima = local_extrema(dEnergy, false, 1, length(dEnergy));
minima = sortrows([dEnergy(minima); minima]')'; minima = minima(2,:);

% Find local maxima
maxima = local_extrema(dEnergy, true, 1, length(dEnergy));
maxima = sortrows([-dEnergy(maxima); maxima]')'; maxima = maxima(2,:);

% Display displacement energy and locations of maxima/minima
if displayFlag
  figure; hEnergy = axes;
  plot(hEnergy, interval, dEnergy, 'Color', [0 0 0])
  axis([interval(1) interval(end) 0 max(dEnergy)]);
  hold(hEnergy, 'on');
  plot(hEnergy, interval(minima), dEnergy(minima), 'g*', ...
    interval(maxima), dEnergy(maxima), 'r*');
  hold(hEnergy, 'off');
  xlabel('Time (ms)')
  ylabel('\partial Energy')
end

% Find transient and stable (defined as not-transient) states
transient = transient_states(dEnergy, maxima, minima);
transient = sortrows(transient);
stable = stable_states(dEnergy, maxima, minima, transient);
stable = sortrows(stable);

% Get list of transient and stable state intervals
extrema = clean_flow_states(transient, stable, samplingInterval);
transient = extrema(extrema(:,3) > 1-eps, 1:2); transientPoints = [];
for m = 1:length(transient)
  transientPoints = [transientPoints transient(m,1):transient(m,2)];
end
stable = extrema(extrema(:,3) < eps, 1:2); stablePoints = [];
for m = 1:length(stable)
  stablePoints = [stablePoints stable(m,1):stable(m,2)];
end

% Display microstate interval on displaced energy curve
if displayFlag
  for m = 1:size(extrema,1)
    if abs(extrema(m,3)) < eps
      type = 'g';
    elseif extrema(m,3) > 1-eps
      type = 'r';
    end
    
    hold(hEnergy, 'on');
    area(hEnergy, interval(extrema(m,1):extrema(m,2)), ...
      dEnergy(extrema(m,1):extrema(m,2)), 'FaceColor', type);
    hold(hEnergy, 'off');
  end
end


end

%% ===== CLEAN SMALL INTERVALS =====
function extrema = clean_flow_states(transient, stable, samplingInterval)

minInterval = floor(0.002/samplingInterval);
if minInterval < 1
  minInterval = 1;
end

% Swallow intervals that are of short length into intervals of longer length
extrema = sortrows([transient ones(size(transient,1), 1); ...
  stable zeros(size(stable,1), 1)]);
for m = 2:size(extrema,1)
  if extrema(m,2) < extrema(m,1) + minInterval
    if extrema(m-1,2) > extrema(m,1) - minInterval
      if extrema(m,2)-extrema(m,1) > extrema(m-1,2)-extrema(m-1,1)
        tag = extrema(m,3);
      else
        tag = extrema(m-1,3);
      end
      extrema(m-1,2) = extrema(m,2); % 2nd interval's beginning is 1st interval
      extrema(m,1) = extrema(m-1,1); % 1st interval's end is 2nd interval
      extrema(m-1,3) = tag; % Both get same label ...
      extrema(m,3) = tag; % ... of the bigger interval
    elseif m < size(extrema,1) && extrema(m,2) > extrema(m+1,1) - minInterval
      if extrema(m,2)-extrema(m,1) > extrema(m+1,2)-extrema(m+1,1)
        tag = extrema(m,3);
      else
        tag = extrema(m+1,3);
      end
      extrema(m,2) = extrema(m+1,2); % 2nd interval's beginning is 1st interval
      extrema(m+1,1) = extrema(m,1); % 1st interval's end is 2nd interval
      extrema(m,3) = tag; % Both get same label ...
      extrema(m+1,3) = tag; % ... of the bigger interval
    else
      extrema(m,1) = max(extrema(m,1) - minInterval, 1); % 2nd interval's beginning is 1st interval
      extrema(m,2) = min(extrema(m,2) + minInterval, length(dEnergy)); % 1st interval's end is 2nd interval
    end
  end
end

% Merge consecutive states of the same type
for m = 2:size(extrema,1)
  if abs(extrema(m,3)-extrema(m-1,3)) < eps
    n = m+1;
    while n <= size(extrema,1) && abs(extrema(n,3)-extrema(n-1,3)) < eps
      n = n+1;
    end      
    extrema((m-1):(n-2),2) = extrema(n-1,2); % 2nd interval's beginning is 1st interval
    extrema(m:(n-1),1) = extrema(m-1,1); % 1st interval's end is 2nd interval
  end
end

% Prune list down to unique states
extrema([false; diff(extrema(:,1)) < eps], :) = [];

end

%% ===== INTERVALS OF TRANSIENT STATES =====
function transient = transient_states(dEnergy, maxima, minima)
% TRANSIENT_STATES    Determine intervals of fast activity, starting
%                     from peak of displacement energy to sufficiently
%                     close to valleys of displacement activity
% INPUTS:
%   dEnergy       - displacement energy in flow
%   maxima        - time points of maximal flow
%   minima        - time points of minimal flow
% OUTPUTS:
%   transient     - List where each row is a 2-element pair of an interval
%                   where flow is "fast"

transient = []; minima = sort(minima);

for m = 1:length(maxima)
  middle = maxima(m); value = dEnergy(middle);
  
  % Threshold between states is halfway between max and min of displacement
  before = minima(find(minima < middle, 1, 'last')); % Last stable point before max
  if isempty(before)
    before = 0;
    b = 0; % If no stable point before max, use 0 as last stable dEnergy
  else
    b = dEnergy(before); % Otherwise, get last stable dEnergy
  end
  
  after = minima(find(minima > middle, 1, 'first')); % First stable point after max
  if isempty(after)
    after = length(dEnergy)+1;
    a = 0; % If no stable point after max, use 0 as next stable dEnergy
  else
    a = dEnergy(after); % Otherwise, get next stable dEnergy
  end
  
  threshold = value - (value - max(b, a)) * 0.7; % Threshold of transient activity
  
  % Find beginning and end of interval of displacement above curve
  begin = find(dEnergy(1:(middle-1)) <= threshold, 1, 'last'); % Last time before
  stop = find(dEnergy((middle+1):end) <= threshold, 1, 'first') + middle; % First time after

  % Current interval cannot include stable state positions
  if isempty(begin) || begin <= before
    begin = before+1;
  end
  if isempty(stop) || stop >= after
    stop = after-1;
  end
  
  % Label microstate
  transient = [transient; begin stop];
end

end

%% ===== INTERVALS OF STABLE STATES =====
function stable = stable_states(dEnergy, maxima, minima, transient)
% STABLE_STATES    Determine intervals of slow activity, starting
%                  from valleys of displacement energy to sufficiently
%                  close to peaks of displacement activity. This is run
%                  after TRANSIENT_STATES, so as to ensure a stable state
%                  is disjoint from all transient states
% INPUTS:
%   dEnergy       - displacement energy in flow
%   maxima        - time points of maximal flow
%   minima        - time points of minimal flow
%   transient     - List where each row is a 2-element pair of an interval
%                   where flow is "fast", used to ensure disjoint intervals
%                   between all states (transient or stable)
% OUTPUTS:
%   stable              - List where each row is a 2-element pair
%                         containing the start and stop of a stable state

dEnergy = -dEnergy; stable = []; maxima = sort(maxima);

for m = 1:length(minima)
  middle = minima(m); value = dEnergy(middle);
  
  % Threshold between states is halfway between min and max of displacement
  before = maxima(find(maxima < middle, 1, 'last')); % Last transient point before min
  if isempty(before)
    before = 0;
    b = 0; % If no transient point before max, use 0 as last transient dEnergy
  else
    b = dEnergy(before); % Otherwise, get last transient dEnergy
  end
  
  after = maxima(find(maxima > middle, 1, 'first')); % First transient point after min
  if isempty(after)
    after = length(dEnergy) + 1;
    a = 0; % If no transient point after max, use 0 as next transient dEnergy
  else
    a = dEnergy(after); % Otherwise, get next transient dEnergy
  end
  
  threshold = value - (value - max(b, a)) * 0.7; % Threshold of transient activity
  
  % Find beginning and end of interval of displacement above curve
  begin = find(dEnergy(1:(middle-1)) <= threshold, 1, 'last'); % Last time before
  stop = find(dEnergy((middle+1):end) <= threshold, 1, 'first') + middle; % First time after

  % Current interval cannot start earlier than end of last interval
  if isempty(begin) || begin <= before 
    begin = before+1;
  end
  if isempty(stop) || stop >= after
    stop = after-1;
  end
  
  % Trim interval if it encroaches on a transient state
  for m = 1:size(transient,1)
    if transient(m,1) < begin && begin < transient(m,2)
      begin = transient(m,2);
    elseif transient(m,1) < stop && stop < transient(m,2)
      stop = transient(m,1);
    end
  end
  
  % Label microstate
  if stop-begin >= 1
    stable = [stable; begin stop];
  end
end

end

%% ===== LOCAL EXTREMA OF A CURVE =====
function extrema = local_extrema(signal, maxOrMin, tStart, tEnd)
% LOCAL_MINIMA 	Find locations of local extrema in signal
% INPUTS:
%   signal            - curve for which we find maxima OR minima
%   maxOrMin          - find local maxima (true) or local minima (false)
%   tStart            - start of search
%   tEnd              - end of search
%
% OUTPUTS:
%   extrema           - Locations of local extrema

% Preprocessing: smoothing of signal for initial extrema
if maxOrMin % Local maxima == local minima of negative
  signal = -1*signal;
end
valleys = []; smoothingFilter = [1 1 1]/3; s = signal;
s = conv(s, smoothingFilter, 'same');
s(tStart) = signal(tStart); s(tEnd) = signal(tEnd);
s = conv(s, smoothingFilter, 'same');
s(tStart) = signal(tStart); s(tEnd) = signal(tEnd);
s = conv(s, smoothingFilter, 'same');
s(tStart) = signal(tStart); s(tEnd) = signal(tEnd);
s = conv(s, smoothingFilter, 'same');
s(tStart) = signal(tStart); s(tEnd) = signal(tEnd);
s = conv(s, smoothingFilter, 'same');
s(tStart) = signal(tStart); s(tEnd) = signal(tEnd);

% Find local minima (of flipped signal if maxima desired)

for t = (tStart+2):(tEnd-1)
  if s(t) < s(t-1) 
    if s(t) < s(t+1) % Definite dip
      valleys(end+1) = t;
    elseif s(t) < s(t-1) && s(t) < s(t+1) + 1e-8*abs(s(t)) % Plateau
      tEnd = t+1;
      while abs(s(tEnd)-s(tEnd+1)) < 1e-8*abs(s(tEnd)) && tEnd < (length(s)-1) % Ride plateau to end
        tEnd = tEnd+1;
      end
      valleys(end+1) = floor((t+tEnd)/2);
      t = tEnd;
    end
  end
end

% Ensure minimum over small range (5 samples)
extrema = [];
for m = 1:length(valleys)
  jitter = valleys(m) + (-2:2);
  jitter = jitter(1 <= jitter & jitter <= length(signal));
  [syed, idx] = min(signal(jitter));
  extrema(m) = idx + jitter(1) - 1;
end

% Don't use first or last time as extremum
extrema(extrema <= tStart | extrema >= tEnd) = [];
extrema = unique(extrema);

end

%% ===== TESSELATION NORMALS =====
function [gradientBasis, triangleAreas, FaceNormals] = ...
  geometry_tesselation(Faces, Vertices, dimension)
% GEOMETRY_TESSELATION    Computes some geometric quantities from a surface
% 
% INPUTS:
%   Faces           - triangles of tesselation
%   Vertices        - coordinates of nodes
%   dimension       - 3 for scalp or cortical surface (default)
%                     2 for plane (channel cap, etc)
% OUTPUTS:
%   gradientBasis   - gradient of basis function (FEM) on each triangle
%   triangleAreas 	- area of each triangle
%   FaceNormals    - normal of each triangle 

% Edges of each triangles
u = Vertices(Faces(:,2),:)-Vertices(Faces(:,1),:);
v = Vertices(Faces(:,3),:)-Vertices(Faces(:,2),:);
w = Vertices(Faces(:,1),:)-Vertices(Faces(:,3),:);

% Length of each edges and angles bewteen edges
uu = sum(u.^2,2);
vv = sum(v.^2,2);
ww = sum(w.^2,2);
uv = sum(u.*v,2);
vw = sum(v.*w,2);
wu = sum(w.*u,2);

% 3 heights of each triangle and their norm
h1 = w-((vw./vv)*ones(1,dimension)).*v;
h2 = u-((wu./ww)*ones(1,dimension)).*w;
h3 = v-((uv./uu)*ones(1,dimension)).*u;
hh1 = sum(h1.^2,2);
hh2 = sum(h2.^2,2);
hh3 = sum(h3.^2,2);

% Gradient of the 3 basis functions on a triangle 
gradientBasis = cell(1,dimension);
gradientBasis{1} = h1./(hh1*ones(1,dimension));
gradientBasis{2} = h2./(hh2*ones(1,dimension));
gradientBasis{3} = h3./(hh3*ones(1,dimension));

% Remove pathological gradients
indices1 = find(sum(gradientBasis{1}.^2,2)==0|isnan(sum(gradientBasis{1}.^2,2)));
indices2 = find(sum(gradientBasis{2}.^2,2)==0|isnan(sum(gradientBasis{2}.^2,2)));
indices3 = find(sum(gradientBasis{3}.^2,2)==0|isnan(sum(gradientBasis{3}.^2,2)));

min_norm_grad = min([ ...
  sum(gradientBasis{1}(sum(gradientBasis{1}.^2,2) > 0,:).^2,2); ...
  sum(gradientBasis{2}(sum(gradientBasis{2}.^2,2) > 0,:).^2,2); ...
  sum(gradientBasis{3}(sum(gradientBasis{3}.^2,2) > 0,:).^2,2) ...
  ]);

gradientBasis{1}(indices1,:) = repmat([1 1 1]/min_norm_grad, length(indices1), 1);
gradientBasis{2}(indices2,:) = repmat([1 1 1]/min_norm_grad, length(indices2), 1);
gradientBasis{3}(indices3,:) = repmat([1 1 1]/min_norm_grad, length(indices3), 1);

% Area of each face
triangleAreas = sqrt(hh1.*vv)/2;
triangleAreas(isnan(triangleAreas)) = 0;

% Calculate normals to surface at each face
if dimension == 3
    FaceNormals = cross(w,u);
    FaceNormals = FaceNormals./repmat(sqrt(sum(FaceNormals.^2,2)),1,3);
else
    FaceNormals = [];
end

% % Calculate normals to surface at each vertex (from normals at each face)
% VertNormals = zeros(size(Vertices,1),3);
% bst_progress('start', 'Optical Flow', ...
%   'Computing normals to surface at every vertex ...', 1, size(Faces,1));
% for facesIdx=1:size(Faces,1); 
%   VertNormals(Faces(facesIdx,:),:) = ...
%     VertNormals(Faces(facesIdx,:),:) + ...
%     repmat(FaceNormals(facesIdx,:), [3 1]);
%   
%   if mod(facesIdx,20) == 0
%     bst_progress('inc', 20); % Update progress bar
%   end
% end 
% bst_progress('stop');
% 
% % Normalize perpendicular-to-surface vectors for each vertex
% VertNormals = VertNormals ./ ...
%   repmat(sqrt(sum(VertNormals.^2,2)),1,3);
% VertNormals(isnan(VertNormals)) = 0; % For pathological anatomy

end