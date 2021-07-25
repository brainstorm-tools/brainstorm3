function [A,Sigma] = YuleWalker_Mask(Gamma, A_mask)

[N,~,q] = size(Gamma);
p = q - 1;

% Creo le matrici che mi servono per il conto
Psi = zeros(N*p);
G = reshape(Gamma(:,:,2:end),[N,N*p]);
% B_mask = reshape(B_mask,[N,N*p]);
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

% Mi muovo riga per riga
A = zeros(N,N*p);

for i = 1:N
    % Vedo nella maschera quali elementi fisso a zero
    ind = find(A_mask(i,:) ~= 0);
    Psi_t = Psi(ind,ind);
    G_t = G(i,ind);
    
    A(i,ind) = G_t / Psi_t; 
end

Sigma = Gamma(:,:,1) - A * G';

end

