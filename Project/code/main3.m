%% Initial Section 

format long

params.HHSOLVER_STEPS = 400; % How precise should hhsolver solution be
params.ALPHA_NUM = 100; % How many different angles should be tested
params.ETA_TRAPEZOID_STEPS = 800; % How many steps used in integrating for eta (for x and y domain individually)
params.GAUSS_NEWTON_RUNS = 12; % How many iterations Gauss-Newton algorithm should run
params.DERIV_STEP = 0.000001; % Step size in calculating derivatives (for I_c, I_s)

% INSTRUCTIONS FOR RUNNING:
%   Before running any question sections, run the initial section to
%   initialize general variables and functions (The one we are in right now)
%
%   Each question can tehreafter be run independetly of eachother or
%   consecutively, by running the full program. All helper functions are at the bottom of the
%   file.
%   
%   See Section for Question 6 for instructions on running specific problem
%   files.




%%%%%% Needed for all/most questions %%%%%%

% General Functions
S0 = @(r) cos(24*sqrt(r)).*exp(-900*r);
v_c = @(x, y, alpha, omega) cos(omega.*(x.*cos(alpha) + y.*sin(alpha)));
v_s = @(x, y, alpha, omega) sin(omega.*(x*cos(alpha) + y*sin(alpha)));

% General constants for these parts
OMEGA = 19;
AMPLITUDE = 1;
X_SOURCE  = 0.45;
Y_SOURCE  = 0.2;
NOISE_LEVEL = 10; % Add noise to sound boundary data

etaIntegrand = @(x,y, OMEGA) S0(x.^2+y.^2).*cos(OMEGA*x);
eta = trapInt2D(params.ETA_TRAPEZOID_STEPS, etaIntegrand, OMEGA);


%% Question 1
    
disp(["Eta: ", num2str(eta)]);


%% Question 2
S = @(x,y) AMPLITUDE*S0((x-X_SOURCE).^2+(y-Y_SOURCE).^2);
[B,Sol] = hhsolver(OMEGA,S,params.HHSOLVER_STEPS);

plotFields(B, Sol, S)


%% Question 3
S = @(x,y) AMPLITUDE*S0((x-X_SOURCE).^2+(y-Y_SOURCE).^2);
[B,Sol] = hhsolver(OMEGA,S,params.HHSOLVER_STEPS);

% Generate a list of angles for test waves to use in inverse problem
% equations
alphas = linspace(0, 2*pi, params.ALPHA_NUM);
Ic_alphas = zeros(length(alphas), 1);
for i=1:length(alphas)
    Ic_alphas(i) = getIc_alpha(B, alphas(i), OMEGA, v_c);
end

accurate_guess = [1.05, 0.4, 0.25];
problem_coeffs = gaussNewton(params.GAUSS_NEWTON_RUNS, length(alphas), accurate_guess, eta, OMEGA, alphas, Ic_alphas);
amplitude = problem_coeffs(1);
x0 = problem_coeffs(2);
y0 = problem_coeffs(3);

disp(['Omega: ', num2str(OMEGA)])
disp(['Amplitude: ', num2str(amplitude, 15)])
disp(['x0: ', num2str(x0, 15)])
disp(['y0: ', num2str(y0, 15)])   


%% Question 4
S = @(x,y) AMPLITUDE*S0((x-X_SOURCE).^2+(y-Y_SOURCE).^2);
[B,Sol] = hhsolver(OMEGA,S,params.HHSOLVER_STEPS);

levels = [1e-2, 1e-1, 0.5, 1.0];
figure;
for k=1:length(levels)
    lvl = levels(k);
    gnoise = B.un + max(abs(B.un)) * randn(size(B.un)) * lvl;
    subplot(2,2,k);
    plot(B.s, B.un,    'b-'); hold on;
    plot(B.s, gnoise,'r.');
    hold off;
    title(['g = ',num2str(lvl)]);
    xlabel('s'); ylabel('g(s)');
    axis tight; grid on;
end


%% Question 5
S = @(x,y) AMPLITUDE*S0((x-X_SOURCE).^2+(y-Y_SOURCE).^2);
[B,Sol] = hhsolver(OMEGA,S,params.HHSOLVER_STEPS);

alphas = linspace(0, 2*pi, params.ALPHA_NUM);
Ic_alphas = zeros(length(alphas), 1);
for i=1:length(alphas)
    Ic_alphas(i) = getIc_alpha(B, alphas(i), OMEGA, v_c);
end

startGuess = getStartGuess(B, eta, OMEGA, v_c, v_s, params.DERIV_STEP);
problem_coeffs = gaussNewton(params.GAUSS_NEWTON_RUNS, length(alphas), startGuess, eta, OMEGA, alphas, Ic_alphas);
amplitude = problem_coeffs(1);
x0 = problem_coeffs(2);
y0 = problem_coeffs(3);

disp("Start guess:")
disp(startGuess)
disp(['Omega: ', num2str(OMEGA)])
disp(['Amplitude: ', num2str(amplitude, 15)])
disp(['x0: ', num2str(x0, 15)])
disp(['y0: ', num2str(y0, 15)])   


%% Question 6
% Instructions:
%   Change SOURCE_NUM to the corresponding problem number you wish to
%   solve.

SOURCE_NUM = 1;

filenames = ["source1.mat", "source2.mat", "source3.mat", "source4.mat", "source5.mat"];

file = load(filenames(SOURCE_NUM));
OMEGA = file.omega;
B = file.B;

[amplitude, x0, y0, eta, alphas, Ic_alphas] = solveSoundProblem(B, OMEGA, S0, v_c, v_s, params);
disp(['Omega: ', num2str(OMEGA)])
disp(['Amplitude: ', num2str(amplitude, 15)])
disp(['x0: ', num2str(x0, 15)])
disp(['y0: ', num2str(y0, 15)])

SFunc = @(x,y) amplitude*S0((x-x0).^2+(y-y0).^2);
[estimatedB, estimatedSol] = hhsolver(OMEGA,SFunc,params.HHSOLVER_STEPS); 
plotEstimatedFields(B, estimatedB, estimatedSol, SFunc);




%%%%%% Helper functions %%%%%%


% Fully encapsulates each step from Questions 1-5, returns estimated
% solution parameters plus intermediate values.
function [amplitude, x0, y0, eta, alphas, Ic_alphas] = solveSoundProblem(BB, omega, S0Func, v_c, v_s, params)
    etaIntegrand = @(x,y, omega) S0Func(x.^2+y.^2).*cos(omega*x);
    eta = trapInt2D(params.ETA_TRAPEZOID_STEPS, etaIntegrand, omega);
    
    alphas = linspace(0, 2*pi, params.ALPHA_NUM);
    Ic_alphas = zeros(length(alphas), 1);
    for i=1:length(alphas)
        Ic_alphas(i) = getIc_alpha(BB, alphas(i), omega, v_c);
    end

    startGuess = getStartGuess(BB, eta, omega, v_c, v_s, params.DERIV_STEP);
    problem_coeffs = gaussNewton(params.GAUSS_NEWTON_RUNS, length(alphas), startGuess, eta, omega, alphas, Ic_alphas);
    
    amplitude = problem_coeffs(1);
    x0 = problem_coeffs(2);
    y0 = problem_coeffs(3);
end

% Composite Trapeziod Integration algorithm for 2 dimensions
function I = trapInt2D(n, func, omega)
    a = -4;
    b = 4;
    h = (b - a) / n;
    
    x = linspace(a, b, n+1);
    y = linspace(a, b, n+1);

    I = 0;
    for j1=1:n+1
        for j2 = 1:n+1
            % Trapezoid rule weight logic
            w = 1;
            if j1 == 1 || j1 == n+1
                w = w / 2;
            end
            if j2 == 1 || j2 == n+1
                w = w / 2;
            end
            
            % function eval
            I = I + w*func(x(j1), y(j2), omega);
        end
    end

    I = I * h^2;
end

% Composite Trapeziod Integration algorithm for 1 dimension
function I = numInt(s, integrand)
    n = length(s);
    I = 0;
    for i=1:n-1
        
        h = s(i+1) - s(i);

        I = I + (h/2).*(integrand(i)+integrand(i+1));
    end
end

% Helper function for Gauss-Newton, evaluates equations r_i in
% nonlinear equation system (that make up function F)
function r = func_r(x, N, eta, omega, alphas, Ic_alphas)
    r = zeros(N, 1);
    for j = 1:N
        r(j) = x(1)*eta*cos(omega*x(2)*cos(alphas(j)) + omega*x(3)*sin(alphas(j))) - Ic_alphas(j);
    end
end

% Helper function for Gauss-Newton, evaluates Jacobian for F
function Dr = derivative_r(x, N, eta, omega, alphas)
    Dr = zeros(N, 3);
    for j = 1:N
        Dr(j, :) = [eta*cos(omega*x(2)*cos(alphas(j)) + omega*x(3)*sin(alphas(j))), ...
            -x(1)*omega*cos(alphas(j))*eta*sin(omega*x(2)*cos(alphas(j)) + omega*x(3)*sin(alphas(j))), ...
            -x(1)*omega*sin(alphas(j))*eta*sin(omega*x(2)*cos(alphas(j)) + omega*x(3)*sin(alphas(j)))];
    end
end

% Gauss-Newton method
function x = gaussNewton(k, N, startGuess, eta, omega, alphas, Ic_alphas)
    %x = [1.05, 0.4, 0.25]';
    x = startGuess';
    for i=1:k
        A = derivative_r(x, N, eta, omega, alphas);
        cond_num = cond(A' * A);
        if cond_num > 1e10
            warning('Matrix (A'' * A) is ill-conditioned. Results may be inaccurate.');
        end
        v = (A')*A \ -(A')*func_r(x, N, eta, omega, alphas, Ic_alphas);
        x = x + v;
    end
end

% Three-Point Centered-Difference Differentation 
function deriv = threePointDeriv(func, alpha, h)
    % No need to wrap around alpha values inside [0, 2pi] since
    %   all associated functions are already periodic such that
    %   we only care about the equivalence class.
    f_left = func(alpha-h);
    f_right = func(alpha+h);

    deriv = (f_right - f_left) ./ (2*h);
end

% Function for calculating Ic_alpha values
function Ic_alpha = getIc_alpha(B, alpha, omega, vc_func)
    % Calculate v_c test wave vals for boundary points
    
    vc_vals = vc_func(B.x, B.y, alpha, omega);

    % Integrand for I_c(alpha)
    integrand = B.un .* vc_vals;
    Ic_alpha = numInt(B.s, integrand);
end

% Function for calculating Is_alpha values
function Is_alpha = getIs_alpha(B, alpha, omega, vs_func)
    % Calculate v_s test wave vals for boundary points
    
    
    vs_vals = vs_func(B.x, B.y, alpha, omega);

    % Integrand for I_s(alpha)
    integrand = B.un .* vs_vals;
    Is_alpha = numInt(B.s, integrand);
end

% Function for calculating start guesses for Gauss-Newton method
function startGuess = getStartGuess(B, eta, omega, vc_func, vs_func, h)
    IcHandle = @(a) getIc_alpha(B, a, omega, vc_func);
    IsHandle = @(a) getIs_alpha(B, a, omega, vs_func);

    % Ic values
    Ic_0 = IcHandle(0);
    dIc_0 = threePointDeriv(IcHandle, 0, h);
    dIc_pi2 = threePointDeriv(IcHandle, pi/2, h);

    % Is values
    Is_0 = IsHandle(0);
    Is_pi2 = IsHandle(pi/2);

    a_0 = sqrt(Ic_0.^2 + Is_0.^2) / eta;
    x_0 = dIc_pi2 / (omega * Is_pi2);
    y_0 = -1 * dIc_0 / (omega * Is_0);
    
    startGuess = [a_0, x_0, y_0];
end

% Plots Helmholtz solution data
function plotFields(BB, Sol, sourceModel)
    figure;

    surf(Sol.x,Sol.y,Sol.u)
    view(0,90)
    shading interp
    axis equal

    figure;

    surf(Sol.x,Sol.y,Sol.u)
    shading interp
    light                    
    lighting gouraud       % Tar lång tid när N är stor
    view(-60,60)
    
    figure;
    %surf(Sol.x,Sol.y,Sol.S)
    surf(Sol.x,Sol.y,sourceModel(Sol.x,Sol.y))
    shading interp
    light
    lighting gouraud       % Tar lång tid när N är stor
    colormap('autumn')
    material shiny
    view(-60,60)
    
    figure;
    contour(Sol.x,Sol.y,Sol.u,20)
    axis equal
    hold on
    plot(BB.x,BB.y,'k-','LineWidth',2)
    [c,hnd]=contour(Sol.x,Sol.y,sourceModel(Sol.x,Sol.y),10); %Sol.S,10);
    set(hnd,'Color','k','LineWidth',1.5)
    hold off
    axis off

    figure;
    plot3(BB.x,BB.y,BB.un,'b-','LineWidth',2) % Actual data
    hold on
    contour(Sol.x,Sol.y,Sol.u,20)
    plot3(BB.x,BB.y,zeros(size(BB.x)),'k-','LineWidth',2)
    hold off
        
    figure;
    mesh(Sol.x,Sol.y,Sol.u)
end

% Plots comparison between problem data and recovered solution data
function plotEstimatedFields(BB, estimatedB, Sol, sourceModel)
    figure;

    surf(Sol.x,Sol.y,Sol.u)
    view(0,90)
    shading interp
    axis equal

    figure;

    surf(Sol.x,Sol.y,Sol.u)
    shading interp
    light                    
    lighting gouraud       % Tar lång tid när N är stor
    view(-60,60)
    
    figure;
    %surf(Sol.x,Sol.y,Sol.S)
    surf(Sol.x,Sol.y,sourceModel(Sol.x,Sol.y))
    shading interp
    light
    lighting gouraud       % Tar lång tid när N är stor
    colormap('autumn')
    material shiny
    view(-60,60)
    
    figure;
    contour(Sol.x,Sol.y,Sol.u,20)
    axis equal
    hold on
    plot(BB.x,BB.y,'k-','LineWidth',2)
    [c,hnd]=contour(Sol.x,Sol.y,sourceModel(Sol.x,Sol.y),10); %Sol.S,10);
    set(hnd,'Color','k','LineWidth',1.5)
    hold off
    axis off

    figure;
    plot3(BB.x,BB.y,BB.un,'b-','LineWidth',2) % Actual data
    hold on
    plot3(estimatedB.x,estimatedB.y,estimatedB.un,'r-','LineWidth',2) % Estimated data
    contour(Sol.x,Sol.y,Sol.u,20)
    plot3(BB.x,BB.y,zeros(size(BB.x)),'k-','LineWidth',2)
    hold off
        
    figure;
    mesh(Sol.x,Sol.y,Sol.u)
end




%%%%%% Currently unused %%%%%%

% Use to verify that Ic_alphas were being calculated correctly
function plotAlphas(alphas, Ic_alphas, aa, xs, ys, omega, eta, v_c)
    % Compute the right-hand side: aa * eta * v_c
    vc_vals = zeros(length(alphas), 1);
    for i = 1:length(alphas)
        vc_vals(i) = v_c(xs, ys, alphas(i), omega);
    end
    rhs = aa * eta * vc_vals;
    figure;
    plot(alphas, Ic_alphas, 'b-'); 
    hold on;
    grid on;
    plot(alphas, rhs, 'r--');
    hold off;
end

