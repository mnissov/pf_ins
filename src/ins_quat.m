close all; clear; clc
%% PF INS implementation
addpath(genpath('../toolbox'))
rng(42);

%% generate data
% artificial
Ts = [0.01; 1];
Tf = 200;
turn_rate = 2.5;

add_noise = 2;
gen_data_complex

meas_noise = R_gnss;
sampling_ratio = gnss.Ts/imu.Ts;

%% initialize PF
x0 = [
    zeros(3,1); % pos
    zeros(3,1); % vel
    rotm2quat(Rz(0))'; % quat
];
P0 = diag([
    1*ones(3,1); % pos
    1e-3*ones(3,1); % vel
    1e-3*ones(4,1); % quat
]);
[nx,~] = size(x0);
% process_noise = diag([
%     1e-4*ones(3,1); % pos
%     1e1*R_acc(1)*ones(3,1); % vel
%     1e0*R_gyro(1)*ones(9,1); % quat
% ]);
process_noise = diag([
    1e-8*ones(3,1);         % pos
    1e0*R_acc(1)*ones(3,1);     % vel
    1e0*R_gyro(1)*ones(4,1);    % quat
]);

pf = pf_init(@(x,u) state_fcn(x,u,imu.Ts,process_noise),...
    @meas_likelihood,...
    1e3, x0, P0, 'uniform',...
    1*meas_noise);
pf.ratio = 2/3;
% pf = particleFilter(@(x,u) state_fcn(x,u,imu.Ts,process_noise),...
%     @(p,z) meas_likelihood(p,z,meas_noise));
% initialize(pf, 1e3, x0, P0);

%% simulate
xV = zeros(numel(gnss.t), nx);
xV(1,:) = x0;
pV = zeros(numel(gnss.t), nx);
pV(1,:) = diag(P0);

ortho_count = 0;
ortho_error = zeros(numel(gnss.t),1);
for k=1:numel(gnss.t)
    pf = pf_correct(pf, gnss.meas(k,:));
    [xV(k,:), pV(k,:)] = pf_estimate(pf);
%     correct(pf, gnss.meas(k,:)');
%     xV(k,:) = pf.State;
%     pV(k,:) = diag(pf.StateCovariance);
    
    figure(2)
    scatter3(pf.particles(2,:), pf.particles(1,:), pf.weights,...
        10,'filled')
    title(strcat("iteration number ",num2str(k)))
    
    R = quat2rotm(xV(k,7:10));
    ortho_error(k) = norm(eye(3)-R'*R,'fro');
    if ortho_error(k)>=1e-3
        ortho_count = ortho_count+1;
    end
    
    for l=1:sampling_ratio
        pf = pf_predict(pf, imu.meas(sampling_ratio*(k-1)+l,:));
%         predict(pf, imu.meas(sampling_ratio*(k-1)+l,:)');
    end
end

opts = {'interpreter','latex','fontsize',14};

figure(2)
scatter3(pf.particles(2,:), pf.particles(1,:), pf.weights,...
    10,'filled')
title(strcat("iteration number ",num2str(k)))
xlabel('$p_e$ $[m]$',...
    opts{:})
ylabel('$p_n$ $[m]$',...
    opts{:})
zlabel('$w$',...
    opts{:})

%% plotting
figure(1)
clf
hold on
plot(gnss.pos(:,2), gnss.pos(:,1),...
    '--','linewidth',2)
plot(gnss.meas(:,2), gnss.meas(:,1),...
        'ro')
plot(xV(:,2), xV(:,1),...
        'kx','markersize',8)
grid on
xlabel('east $[m]$',...
    opts{:})
ylabel('north $[m]$',...
    opts{:})
legend({'$p^t$','$\tilde{p}^t$','$\hat{p}^t$'},...
    opts{:})

figure(3)
clf
subplot(211)
hold on
plot(gnss.t, abs(gnss.pos(:,1)-gnss.meas(:,1)))
plot(gnss.t, abs(gnss.pos(:,1)-xV(:,1)))
grid on
subplot(212)
hold on
plot(gnss.t, abs(gnss.pos(:,2)-gnss.meas(:,2)))
plot(gnss.t, abs(gnss.pos(:,2)-xV(:,2)))
grid on

[sqrt(mean((gnss.pos(:,1)-xV(:,1)).^2)), sqrt(mean((gnss.pos(:,2)-xV(:,2)).^2))]

figure(6)
clf
subplot(211)
hold on
plot(imu.t, imu.vel(:,1))
plot(gnss.t, xV(:,4),...
    'x')
grid on
subplot(212)
hold on
plot(imu.t, imu.vel(:,2))
plot(gnss.t, xV(:,5),...
    'x')
grid on

figure(7)
plot(gnss.t, ortho_error,...
    'linewidth',2)
grid on
xlabel('Time $[s]$',...
    opts{:})
ylabel('Orthonormal Error $||I - (\hat{R}_b^t)^T \hat{R}_b^t||$',...
    opts{:})

function [ xk1 ] = state_fcn( x,u,Ts,process_noise )
    dither = chol(process_noise,'lower')*randn(size(x));
    
    xdot = full_state_quat(0,x,u)+dither;
    
    xk1 = x + Ts*(xdot);
    xk1(7:10,:) = quatnorm(xk1(7:10,:));
end
function [ y ] = meas_fcn( x )
    y = x(1:3,:);
end
function [ likelihood ] = meas_likelihood( particles,meas,meas_noise )
    [nz,~] = size(meas);
    pred_meas = meas_fcn(particles);
    
    residual = pred_meas-meas;
    meas_error_prod = dot(residual, meas_noise\residual, 1);
    likelihood = 1/sqrt((2*pi).^nz*det(meas_noise))*exp(-0.5*meas_error_prod);
end