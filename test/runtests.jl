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

        result = sovova_multi(curve; maxevals=20_000)
        @test result.objective < 1e-8
        @test length(result.kya) == 1
        @test length(result.kxa) == 1
    end

    @testset "mateus1 experimental data" begin
        curve = ExtractionCurve(
            t     = [0.0, 0.0, 5.0, 5.0, 10.0, 10.0, 15.0, 15.0, 20.0, 20.0,
                     30.0, 30.0, 45.0, 45.0, 60.0, 60.0, 75.0, 75.0, 90.0, 90.0,
                     110.0, 110.0, 135.0, 135.0, 155.0, 155.0, 180.0, 180.0,
                     210.0, 210.0, 240.0, 240.0, 270.0, 270.0, 300.0, 300.0],
            m_ext = [0.0000, 0.0000, 0.1097, 0.0935, 0.2571, 0.2265,
                     0.3894, 0.3507, 0.5228, 0.4746, 0.7872, 0.7270,
                     1.1633, 1.0636, 1.4848, 1.3746, 1.7484, 1.6411,
                     1.9751, 1.8913, 2.2485, 2.1785, 2.5630, 2.5539,
                     2.7584, 2.7690, 3.0323, 3.0527, 3.3022, 3.3416,
                     3.5332, 3.5906, 3.7349, 3.8130, 3.9260, 4.0177],
            temperature       = 333.15,
            porosity          = 0.7,
            x0                = 0.069,
            solid_density     = 1.32,
            solvent_density   = 0.78023,
            flow_rate         = 9.9,
            bed_height        = 9.2,
            bed_diameter      = 5.42,
            particle_diameter = 0.0337,
            solid_mass        = 100.01,
            solubility        = 0.003166,
            viscosity         = 0.067739,
        )

        result = sovova_multi(curve; maxevals=50_000)

        # Should achieve a reasonable fit
        @test result.objective < 1e-5
        # Parameters should be within physical bounds
        @test 0 < result.kya[1] < 0.05
        @test 0 < result.kxa[1] < 0.005
        @test 0 < result.xk_ratio < 1.0
        @test result.tcer[1] > 0
        # Calculated curve should have correct length
        @test length(result.ycal[1]) == 36
    end
end
