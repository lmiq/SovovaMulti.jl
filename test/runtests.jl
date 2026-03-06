using SovovaMulti
using Test

@testset "SovovaMulti.jl" begin

    @testset "ExtractionCurve construction" begin
        curve = ExtractionCurve(
            t = [5.0, 10.0, 15.0, 20.0, 30.0, 45.0, 60.0, 90.0, 120.0],
            m_ext = [0.1, 0.25, 0.42, 0.58, 0.85, 1.10, 1.28, 1.45, 1.52],
            temperature = 313.15,
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
            viscosity = 0.06,
        )
        # Check SI conversions
        @test curve.t[1] ≈ 5.0 * 60.0
        @test curve.m_ext[1] ≈ 0.1 / 1000.0
        @test curve.solid_density ≈ 1.1 * 1000.0
        @test curve.bed_height ≈ 20.0 / 100.0
        @test curve.diffusivity > 0.0  # computed from Stokes-Einstein
    end

    @testset "simulate produces non-negative output" begin
        curve = ExtractionCurve(
            t = collect(range(5.0, 120.0, length=10)),
            m_ext = collect(range(0.1, 1.5, length=10)),
            temperature = 313.15,
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
            viscosity = 0.06,
        )
        kya = 0.01
        kxa = 0.001
        xk = 0.03
        ycal = SovovaMulti.simulate(curve, kya, kxa, xk)
        @test length(ycal) == 10
        @test all(ycal .>= 0.0)
        # Extraction should be monotonically non-decreasing
        @test all(diff(ycal) .>= -1e-15)
    end

    @testset "sovova_multi fitting (single curve)" begin
        # Generate synthetic data with known parameters, then fit
        curve_for_gen = ExtractionCurve(
            t = collect(range(5.0, 180.0, length=15)),
            m_ext = zeros(15),  # placeholder
            temperature = 313.15,
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
            viscosity = 0.06,
        )

        # Generate "experimental" data with known parameters
        true_kya = 0.02
        true_kxa = 0.002
        true_xk = 0.03
        m_ext_true = SovovaMulti.simulate(curve_for_gen, true_kya, true_kxa, true_xk)

        # Now create curve with this synthetic data (convert back to user units)
        curve = ExtractionCurve(
            t = collect(range(5.0, 180.0, length=15)),
            m_ext = m_ext_true .* 1000.0,  # convert back to g
            temperature = 313.15,
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
            viscosity = 0.06,
        )

        result = sovova_multi(curve; nrestarts=50, maxfun=2000)
        @test result.objective < 1e-8
        @test length(result.kya) == 1
        @test length(result.kxa) == 1
    end
end
