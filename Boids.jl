using LinearAlgebra, Distributions, GLMakie,Makie#Plots

#make a boid struct
#rn just make one st it keeps track of pos,vel

mutable struct Boid
    position::Vector{<:Real}
    velocity::Vector{<:Real}
end
#small constructor for boid with just a position and zero velocity
function Boid(position)
    return Boid(position,zero(position))
end

#since julia is functional functions act on boids instead of acting as methods of classes

#function to generate a velocity that aims on boid to another
function aim(base::Boid,target::Boid,speed)
    #first we check an edge case of the boids being about the same position
    if base.position ≈ target.position
        #when their close just pull out a zero vector
        direction = zero(base.velocity)
    else
        #when their sutable far I want to get the direction from base to traget
        direction = target.position - base.position
        direction /= norm(direction)
    end
    #now direction should either be a unit vector from base -> target or a zero
    #scale by speed and return
    return direction*speed
end
function aim(base::Boid,target::Vector{<:Real},speed)
    #same as orinignal aim but using directly with position vector target instead of boid
    #first we check an edge case of the boids being about the same position
    if base.position ≈ target
        #when their close just pull out a zero vector
        direction = zero(base.velocity)
    else
        #when their sutable far I want to get the direction from base to traget
        direction = target - base.position
        direction /= norm(direction)
    end
    #now direction should either be a unit vector from base -> target or a zero
    #scale by speed and return
    return direction*speed
end

#function to add to a boids velocity
function flap!(base::Boid,v::Vector{<:Real})
    #just add the input velocity to the bases velocity
    base.velocity .+= v
end

#function to make a boid do a step based on kinematic data
#aswell as resets velocity to zero for next flap step
function fly!(base::Boid)
    base.position .+= base.velocity
    base.velocity  = zero(base.velocity)
end

#struc to keep track of a bunch of boids, friends and enemies
struct Dance
    flock::Vector{Boid}
    friends::Vector{Int}
    enemies::Vector{Int}
    center::Vector{<:Real}
end
#function that takes in a vector of boids to create a Dance struc
function Dance(flock::Vector{Boid})
    #get number of boids
    N = size(flock,1)
    #get N random numbers from 1:N to setup both friends and enemies vector
    frnd = rand(1:N,N)
    enms = rand(1:N,N)
    #calculate center as average position
    rmean = sum([d.position for d in flock]) /N
    #return a Dance
    return Dance(flock,frnd,enms,rmean)
end

#now I need to make a step function, each step a Dance should have each boid,
# 1) move a bit closer to center of Dance
# 2) move a bit towards friend
# 3) move a bit away from enemy
function DanceStep!(D::Dance; ω=0.1, λ=0.2, χ=0.2)
    for (d,frni,enmi) in zip(D.flock,D.friends,D.enemies)
        #id the friend and enemy and center
        frn, enm, cnt = D.flock[frni],D.flock[enmi],D.center
        #get a component that is aiming to center
        centerv = aim(d,cnt,ω)
        #get a component that is aiming to friend
        friendv = aim(d,frn,λ)
        #get a component that is aiming to enemy
        enemyv = aim(d,enm,χ)
        #sum all these components
        findir = centerv + friendv - enemyv
        #update this oids velocity based o nthe previouse calculations
        flap!(d,findir)
        #update this boids position
        fly!(d)
    end
end

#I need to make a function that rechooses the friend and enemies list
function NewPartners!(D::Dance)
    #get size of flock
    N = size(D.flock,1)
    #slect k from a poisson distribution
    k = rand(Poisson())
    #get random k dancers whoes partners are being reasigned
    dancers = rand(1:N,k)
    #create new friends and enemies for these k dancers
    frnds = rand(1:N,k)
    enems = rand(1:N,k)
    #use the dancers as index to change friends and enemies apropriatly
    D.friends[dancers] = frnds
    D.enemies[dancers] = enems
end

#plotting utility that takes in a dance and returns x,y 
function DancetoCoor(D::Dance)
    Rx = [boid.position[1] for boid in D.flock]
    Ry = [boid.position[2] for boid in D.flock]
    return Rx,Ry
end

#function to make dance do a step and update some observables
function step(Di::Dance,ObX,ObY,omega,lambda,chi)
    #make dance select new partners
    NewPartners!(Di)
    #make a DanceStep and change any observables to floats
    omegaf = omega[]
    lambdaf = lambda[]
    chif = chi[]
    DanceStep!(Di,ω=omegaf,λ=lambdaf,χ=chif)
    #get plotting values
    newX,newY = DancetoCoor(Di)
    #update observables
    ObX[] = newX
    ObY[] = newY
end

#function that takes in a dance and premakes a plot
function FigInit(Di::Dance)
    #get the plotting positions
    X,Y = DancetoCoor(Di)
    #make them observables
    oX,oY = Observable(X),Observable(Y)
    #initalize a figure
    fig = Figure()
    display(fig)
    #make an axes inside figure and plot dance
    ax = Axis(fig[1,1])
    scatter!(ax,oX,oY)
    #return the figure and observables
    return fig, oX,oY
end

#make a bunch of vectors acting like inital positions
R₀ = Vector.(eachcol(randn(2,1000)))
#setup up boids vector and dance
f = Boid.(R₀)
D = Dance(f)

#initalize a makie figure and observables
fig, ox,oy = FigInit(D)
print("Figure done init")

#make a slider grid for the 3 sliders
lsgrid = labelslidergrid!(fig,
["ω","λ","χ"],
[0:0.01:0.1,0:0.01:0.1,0:0.01:0.1];
formats = [x->"$(round(x,digits=2))" for s in ["o","l","chi"]],
)

#set sliders to zero
set_close_to!(lsgrid.sliders[1],0)
set_close_to!(lsgrid.sliders[2],0)
set_close_to!(lsgrid.sliders[3],0)

#fix slider layout (Makie is weird so I dont realy know why this works)
sublayout = GridLayout(height=150)
fig[2,1] = sublayout
fig[2,1] = lsgrid.layout

#make an observables that relate to the params of the simulation
#these obervables are tied to the sliders

oω = lsgrid.sliders[1].value
oλ = lsgrid.sliders[2].value
oχ = lsgrid.sliders[3].value

#put interactive simulation in a while loop
while true
    #update simulation
    step(D,ox,oy,oω,oλ,oχ)
    #sleep
    sleep(0.00001)
end
