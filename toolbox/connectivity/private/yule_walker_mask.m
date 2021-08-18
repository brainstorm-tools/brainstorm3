function [A,Sigma] = yule_walker_mask(Gamma, A_mask)

% YULE_WALKER_MASK      Solve the Yule-Walker system of equations under
%                       some constraints on the couplings.
%
% Inputs:
%   Gamma               - Correlations of the time series 
%                         [N x N x (p+1)]
%   A_mask              - Mask to cut off some couplings 
%                         [N x N]
%
% Outputs:
%   A                 - Couplings of the VAR model 
%                       [N x Np, where Np = N x p]
%   Sigma             - Residuals covariance matrix
%                       [N x N]

[N,~,q] = size(Gamma);
p = q - 1;

% Initialize the matrices used for the evaluation
Psi = zeros(N*p);
G = reshape(Gamma(:,:,2:end),[N,N*p]);
A_mask = repmat(A_mask,[1,p]);

for i = 1:p
    for j = 1:p
        k = j - i; 
        if (k > 0)  % Colonna > Riga = metà superiore destra
            Psi((i-1)*N+1:i*N, (j-1)*N+1:j*N) = Gamma(:,:,k + 1);
        else
            Psi((i-1)*N+1:i*N, (j-1)*N+1:j*N) = Gamma(:,:,abs(k) + 1)';
        end
    end
end

% Solve row-by-row
A = zeros(N,N*p);

for i = 1:N
    % Solve only for the indices that aren't masked off
    ind = find(A_mask(i,:) ~= 0);
    Psi_t = Psi(ind,ind);
    G_t = G(i,ind);
    
    A(i,ind) = G_t / Psi_t; 
end

Sigma = Gamma(:,:,1) - A * G';

end

